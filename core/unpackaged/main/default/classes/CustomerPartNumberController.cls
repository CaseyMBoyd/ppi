/**
 * @description Portal-facing controller for the Customer Part Number feature.
 * All read methods short-circuit when the Account-level toggle
 * (Enable_Customer_Part_Numbers__c) is off, consolidating RN01 + RN09.
 *
 * Security model: with sharing + Private OWD (internal and external) +
 * criteria-based sharing rules per portal role. A portal user viewing an
 * account reached via the B2B Commerce Account Switcher (parent -> child)
 * needs an explicit sharing rule granting their portal role Read access to
 * Customer_Product_Mapping__c - this does NOT come for free from the
 * switcher itself (AccountContactRelation-based, unrelated to Salesforce
 * record sharing), and is NOT bypassable via WITH SYSTEM_MODE / "without
 * sharing" Apex, because the External Organization-Wide Default is a
 * separately-enforced boundary for external users, deliberately not
 * overridable by system-mode code. Each parent account that uses the
 * switcher needs its own sharing rule entry (see PBPP2-47 follow-up notes).
 * Write paths run after an explicit account guard for Experience users (a
 * portal user can only write into their own account), because
 * system-managed fields (Source_Type__c, Mapping_Composite_Key__c) are
 * intentionally read-only at FLS level and are stamped by controlled code
 * paths.
 */
public with sharing class CustomerPartNumberController {

    // Backstop message for the rare case where the Unique field (not the trigger)
    // raises the duplicate. Kept consistent with the trigger's message so the user
    // sees the same text regardless of which layer catches the duplicate.
    private static final String DUPLICATE_PART_NUMBER_MESSAGE =
        'This Customer Part Number is already mapped on this account.';

    // ---------- Reads ----------

    @AuraEnabled(cacheable=true)
    public static Boolean isFeatureEnabled(Id accountId) {
        return isEnabled(accountId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Customer_Product_Mapping__c> getMappings(Id accountId) {
        if (!isEnabled(accountId)) {
            return new List<Customer_Product_Mapping__c>();
        }
        return [
            SELECT Id, Customer_Part_Number__c, PPI_SKU_Input__c,
                   Product__c, Validation_Status__c, Is_Active__c, Source_Type__c
            FROM Customer_Product_Mapping__c
            WHERE Account__c = :accountId
            ORDER BY Customer_Part_Number__c ASC
        ];
    }

    // Search intercept: translate a customer part number into the PPI SKU
    @AuraEnabled(cacheable=true)
    public static String translateToProductSku(String customerPartNumber, Id accountId) {
        if (String.isBlank(customerPartNumber) || !isEnabled(accountId)) {
            return null;
        }
        List<Customer_Product_Mapping__c> results = [
            SELECT PPI_SKU_Input__c
            FROM Customer_Product_Mapping__c
            WHERE Account__c = :accountId
            AND Customer_Part_Number__c = :customerPartNumber
            AND Is_Active__c = true
            LIMIT 1
        ];
        return results.isEmpty() ? null : results[0].PPI_SKU_Input__c;
    }

    // Display: customer part number for a product (PLP, PDP, Cart, Order Detail)
    @AuraEnabled(cacheable=true)
    public static String getCustomerPartNumberForProduct(Id productId, Id accountId) {
        if (productId == null || !isEnabled(accountId)) {
            return null;
        }
        List<Customer_Product_Mapping__c> results = [
            SELECT Customer_Part_Number__c
            FROM Customer_Product_Mapping__c
            WHERE Account__c = :accountId
            AND Product__c = :productId
            AND Is_Active__c = true
            LIMIT 1
        ];
        return results.isEmpty() ? null : results[0].Customer_Part_Number__c;
    }

    // ---------- Writes ----------

    @AuraEnabled
    public static void saveMapping(Customer_Product_Mapping__c record) {
        if (record == null) {
            throw new AuraHandledException('Record is required.');
        }

        // Safely read Account__c even if the caller passed a partially-queried SObject.
        Id accountId = safeGetAccountId(record);

        // For updates, reload the current Account from the database when the inbound
        // record did not carry it (the trigger reads Account__c on before-update).
        if (record.Id != null) {
            List<Customer_Product_Mapping__c> existing = [
                SELECT Id, Account__c
                FROM Customer_Product_Mapping__c
                WHERE Id = :record.Id LIMIT 1
            ];
            if (existing.isEmpty()) {
                throw new AuraHandledException('Record not found.');
            }
            if (accountId == null) {
                accountId = existing[0].Account__c;
                record.Account__c = accountId;
            }
        }

        if (accountId == null) {
            throw new AuraHandledException('Account is required.');
        }
        assertAccountAccess(accountId);

        if (String.isBlank(record.Source_Type__c)) {
            record.Source_Type__c = 'Portal';
        }

        // Composite key is stamped by the trigger (before insert / before update).
        // A duplicate Customer Part Number violates the unique composite key; surface
        // a clear message for that expected case instead of a generic system error.
        try {
            upsert record;
        } catch (DmlException e) {
            if (isDuplicatePartNumber(e)) {
                throw buildAuraException(DUPLICATE_PART_NUMBER_MESSAGE);
            }
            // Any other DML failure: surface the real reason rather than a generic toast.
            String detail = e.getNumDml() > 0 ? e.getDmlMessage(0) : e.getMessage();
            throw buildAuraException(detail);
        }
    }

    // Returns Account__c without throwing if the field was not selected.
    private static Id safeGetAccountId(Customer_Product_Mapping__c record) {
        try {
            return record.Account__c;
        } catch (System.SObjectException e) {
            return null;
        }
    }

    @AuraEnabled
    public static void deleteMapping(Id recordId) {
        if (recordId == null) {
            return;
        }
        List<Customer_Product_Mapping__c> visible = [
            SELECT Id FROM Customer_Product_Mapping__c
            WHERE Id = :recordId LIMIT 1
        ];
        if (!visible.isEmpty()) {
            delete as user visible;
        }
    }

    // CSV upload: parse + upsert by composite key; validation runs async via trigger
    @AuraEnabled
    public static void processCsvUpload(String csvBase64, Id accountId) {
        if (String.isBlank(csvBase64) || accountId == null) {
            throw new AuraHandledException('No file content received.');
        }
        if (!isEnabled(accountId)) {
            throw new AuraHandledException('Feature is not enabled for this account.');
        }
        assertAccountAccess(accountId);

        String csvContent = EncodingUtil.base64Decode(csvBase64).toString();
        List<Customer_Product_Mapping__c> parsedRecords =
            CsvParserService.parse(csvContent, accountId);

        if (!parsedRecords.isEmpty()) {
            Database.upsert(
                parsedRecords,
                Customer_Product_Mapping__c.Mapping_Composite_Key__c,
                false
            );
        }
    }

    // ---------- Helpers ----------

    private static Boolean isEnabled(Id accountId) {
        if (accountId == null) {
            return false;
        }
        // System mode by intent: the toggle is a feature flag, not user data.
        // Avoids FLS issues on the custom field for admins/portal users not yet
        // granted explicit field permission on the very flag they are checking.
        List<Account> accounts = [
            SELECT Enable_Customer_Part_Numbers__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        return !accounts.isEmpty() && accounts[0].Enable_Customer_Part_Numbers__c;
    }

    // True when the DML failure is the unique composite-key violation raised
    // because the Customer Part Number already exists on the account.
    private static Boolean isDuplicatePartNumber(DmlException e) {
        for (Integer i = 0; i < e.getNumDml(); i++) {
            if (e.getDmlType(i) == System.StatusCode.DUPLICATE_VALUE) {
                return true;
            }
        }
        String msg = e.getMessage();
        return msg != null && msg.containsIgnoreCase('duplicate value found');
    }

    // Builds an AuraHandledException whose message reaches the LWC as
    // error.body.message (setMessage avoids the generic "Script-thrown exception").
    private static AuraHandledException buildAuraException(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }

    // Experience users may only write into their own account
    private static void assertAccountAccess(Id accountId) {
        Id contactAccountId = getRunningUserAccountId();
        if (contactAccountId != null && contactAccountId != accountId) {
            throw new AuraHandledException(
                'You can only manage part numbers for your own account.');
        }
    }

    private static Id getRunningUserAccountId() {
        List<User> users = [
            SELECT Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            AND ContactId != null
            LIMIT 1
        ];
        return users.isEmpty() ? null : users[0].Contact.AccountId;
    }
}