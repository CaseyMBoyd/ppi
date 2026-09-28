/**
 * @description Admin-only cross-account copy of Customer Part Number mappings.
 * Invoked by the "Copy Cross-References to Account(s)" Screen Flow.
 * Any account may be a target — no parent/child relationship required.
 * Copied records re-enter the async validation pipeline (trigger resets them
 * to Pending), guaranteeing SKU integrity on the target account as well.
 */
public with sharing class CustomerPartNumberCopyAction {

    @InvocableMethod(
        label='Copy Customer Part Number Mappings'
        description='Copies mappings from a source account to any target account(s).'
        category='Commerce'
    )
    public static List<CopyResult> copyMappings(List<CopyRequest> requests) {
        List<CopyResult> results = new List<CopyResult>();
        for (CopyRequest req : requests) {
            results.add(processCopy(req));
        }
        return results;
    }

    private static CopyResult processCopy(CopyRequest req) {
        CopyResult result = new CopyResult();

        List<Account> validTargets = [
            SELECT Id FROM Account
            WHERE Id IN :req.targetAccountIds
            AND Id != :req.sourceAccountId
            WITH USER_MODE
        ];
        if (validTargets.isEmpty()) {
            result.errorMessage = 'No valid target accounts found.';
            return result;
        }
        Set<Id> validTargetIds = new Map<Id, Account>(validTargets).keySet();
        // Convert to List for SOQL bind (Set<Id> bind has known platform quirks)
        List<Id> validTargetIdList = new List<Id>(validTargetIds);

        // A target account selected for a copy is meant to see the copied mappings on
        // the storefront, so flip its display toggle on here rather than leaving that
        // as a separate manual step. System mode by intent, same as the flag's
        // read-side treatment in CustomerPartNumberController.isEnabled() — most
        // profiles/permission sets are never granted explicit FLS on this flag field.
        List<Account> accountsToEnable = new List<Account>();
        for (Account target : [
            SELECT Id, Enable_Customer_Part_Numbers__c
            FROM Account
            WHERE Id IN :validTargetIdList
            AND Enable_Customer_Part_Numbers__c != true
        ]) {
            target.Enable_Customer_Part_Numbers__c = true;
            accountsToEnable.add(target);
        }
        if (!accountsToEnable.isEmpty()) {
            update accountsToEnable;
        }

        List<Customer_Product_Mapping__c> sourceMappings = [
            SELECT Customer_Part_Number__c, PPI_SKU_Input__c
            FROM Customer_Product_Mapping__c
            WHERE Id IN :req.sourceMappingIds
            AND Account__c = :req.sourceAccountId
            WITH USER_MODE
        ];
        if (sourceMappings.isEmpty()) {
            result.errorMessage = 'No source mappings found.';
            return result;
        }

        // Duplicate detection by composite key on the targets
        Set<String> existingKeys = new Set<String>();
        for (Customer_Product_Mapping__c existing : [
            SELECT Mapping_Composite_Key__c
            FROM Customer_Product_Mapping__c
            WHERE Account__c IN :validTargetIdList
        ]) {
            existingKeys.add(existing.Mapping_Composite_Key__c);
        }

        Boolean overwrite = req.overwriteExisting == true;
        List<Customer_Product_Mapping__c> toUpsert =
            new List<Customer_Product_Mapping__c>();

        for (Id targetId : validTargetIds) {
            for (Customer_Product_Mapping__c src : sourceMappings) {
                String compositeKey =
                    String.valueOf(targetId) + '_' + src.Customer_Part_Number__c;

                if (existingKeys.contains(compositeKey) && !overwrite) {
                    result.skipped++;
                    continue;
                }

                toUpsert.add(new Customer_Product_Mapping__c(
                    Account__c = targetId,
                    Customer_Part_Number__c = src.Customer_Part_Number__c,
                    PPI_SKU_Input__c = src.PPI_SKU_Input__c,
                    Source_Type__c = 'Copied',
                    Mapping_Composite_Key__c = compositeKey
                ));
            }
        }

        if (!toUpsert.isEmpty()) {
            Database.UpsertResult[] upsertResults = Database.upsert(
                toUpsert,
                Customer_Product_Mapping__c.Mapping_Composite_Key__c,
                false
            );
            for (Database.UpsertResult ur : upsertResults) {
                if (ur.isSuccess()) {
                    result.copied++;
                } else {
                    result.failed++;
                }
            }
        }
        return result;
    }

    public class CopyRequest {
        @InvocableVariable(required=true label='Source Account Id')
        public Id sourceAccountId;

        @InvocableVariable(required=true label='Source Mapping Ids')
        public List<Id> sourceMappingIds;

        @InvocableVariable(required=true label='Target Account Ids')
        public List<Id> targetAccountIds;

        @InvocableVariable(label='Overwrite Existing Mappings')
        public Boolean overwriteExisting;
    }

    public class CopyResult {
        @InvocableVariable public Integer copied;
        @InvocableVariable public Integer skipped;
        @InvocableVariable public Integer failed;
        @InvocableVariable public String errorMessage;

        public CopyResult() {
            copied = 0;
            skipped = 0;
            failed = 0;
            errorMessage = '';
        }
    }
}