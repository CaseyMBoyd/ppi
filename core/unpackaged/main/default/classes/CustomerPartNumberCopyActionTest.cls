/**
 * @description Tests for CustomerPartNumberCopyAction.
 */
@IsTest
private class CustomerPartNumberCopyActionTest {

    private static final String VALID_SKU = 'CPY-VALID-001';

    @TestSetup
    static void setup() {
        Account parent = new Account(Name = 'Parent Corp');
        insert parent;

        insert new List<Account>{
            new Account(Name = 'Branch East', ParentId = parent.Id),
            new Account(Name = 'Branch West', ParentId = parent.Id),
            new Account(Name = 'Stranger Co') // different family, no ParentId (top-level)
        };

        insert new Account(
            Name = 'Stranger Branch',
            ParentId = [SELECT Id FROM Account WHERE Name = 'Stranger Co'].Id
        );

        insert new Product2(
            Name = 'Copy Test Product',
            StockKeepingUnit = VALID_SKU,
            IsActive = true
        );
    }

    private static Id accId(String name) {
        return [SELECT Id FROM Account WHERE Name = :name].Id;
    }

    private static List<Id> insertSourceMappings(Id sourceId, Integer qty) {
        List<Customer_Product_Mapping__c> mappings =
            new List<Customer_Product_Mapping__c>();
        for (Integer i = 0; i < qty; i++) {
            mappings.add(new Customer_Product_Mapping__c(
                Account__c = sourceId,
                Customer_Part_Number__c = 'SRC-' + i,
                PPI_SKU_Input__c = VALID_SKU,
                Source_Type__c = 'Admin'
            ));
        }
        insert mappings;
        return new List<Id>(new Map<Id, Customer_Product_Mapping__c>(mappings).keySet());
    }

    private static CustomerPartNumberCopyAction.CopyRequest buildRequest(
        Id sourceId, List<Id> mappingIds, List<Id> targetIds, Boolean overwrite
    ) {
        CustomerPartNumberCopyAction.CopyRequest req =
            new CustomerPartNumberCopyAction.CopyRequest();
        req.sourceAccountId = sourceId;
        req.sourceMappingIds = mappingIds;
        req.targetAccountIds = targetIds;
        req.overwriteExisting = overwrite;
        return req;
    }

    @IsTest
    static void copy_toSiblingAccount_createsCopiedRecords() {
        Id east = accId('Branch East');
        Id west = accId('Branch West');
        List<Id> mappingIds = insertSourceMappings(east, 2);

        Test.startTest();
        List<CustomerPartNumberCopyAction.CopyResult> results =
            CustomerPartNumberCopyAction.copyMappings(
                new List<CustomerPartNumberCopyAction.CopyRequest>{
                    buildRequest(east, mappingIds, new List<Id>{ west }, false)
                });
        Test.stopTest();

        Assert.areEqual(2, results[0].copied, 'Both mappings must copy');
        Assert.areEqual(0, results[0].skipped);
        Assert.areEqual(0, results[0].failed);

        List<Customer_Product_Mapping__c> copies = [
            SELECT Source_Type__c FROM Customer_Product_Mapping__c
            WHERE Account__c = :west
        ];
        Assert.areEqual(2, copies.size());
        for (Customer_Product_Mapping__c c : copies) {
            Assert.areEqual('Copied', c.Source_Type__c,
                'Copied records must carry Source Type = Copied');
        }
    }

    @IsTest
    static void copy_duplicateWithoutOverwrite_skips() {
        Id east = accId('Branch East');
        Id west = accId('Branch West');
        List<Id> mappingIds = insertSourceMappings(east, 2);

        // Pre-existing duplicate on the target (same part number SRC-0)
        insert new Customer_Product_Mapping__c(
            Account__c = west,
            Customer_Part_Number__c = 'SRC-0',
            PPI_SKU_Input__c = VALID_SKU,
            Source_Type__c = 'Admin'
        );

        Test.startTest();
        List<CustomerPartNumberCopyAction.CopyResult> results =
            CustomerPartNumberCopyAction.copyMappings(
                new List<CustomerPartNumberCopyAction.CopyRequest>{
                    buildRequest(east, mappingIds, new List<Id>{ west }, false)
                });
        Test.stopTest();

        Assert.areEqual(1, results[0].copied, 'Only the non-duplicate copies');
        Assert.areEqual(1, results[0].skipped, 'The duplicate must be skipped');
    }

    @IsTest
    static void copy_duplicateWithOverwrite_overwrites() {
        Id east = accId('Branch East');
        Id west = accId('Branch West');
        List<Id> mappingIds = insertSourceMappings(east, 2);

        insert new Customer_Product_Mapping__c(
            Account__c = west,
            Customer_Part_Number__c = 'SRC-0',
            PPI_SKU_Input__c = 'OLD-SKU',
            Source_Type__c = 'Admin'
        );

        Test.startTest();
        List<CustomerPartNumberCopyAction.CopyResult> results =
            CustomerPartNumberCopyAction.copyMappings(
                new List<CustomerPartNumberCopyAction.CopyRequest>{
                    buildRequest(east, mappingIds, new List<Id>{ west }, true)
                });
        Test.stopTest();

        Assert.areEqual(2, results[0].copied,
            'Overwrite must upsert both, including the duplicate');
        Assert.areEqual(0, results[0].skipped);

        Customer_Product_Mapping__c overwritten = [
            SELECT PPI_SKU_Input__c, Source_Type__c
            FROM Customer_Product_Mapping__c
            WHERE Account__c = :west AND Customer_Part_Number__c = 'SRC-0'
        ];
        Assert.areEqual(VALID_SKU, overwritten.PPI_SKU_Input__c,
            'Overwrite must replace the SKU input');
    }

    @IsTest
    static void copy_targetOutsideFamily_createsCopiedRecords() {
        // Decision (PBPP2-47, 2026-07-24): copying is allowed between any
        // accounts regardless of parent/child structure.
        Id east = accId('Branch East');
        Id stranger = accId('Stranger Co');
        List<Id> mappingIds = insertSourceMappings(east, 1);

        Test.startTest();
        List<CustomerPartNumberCopyAction.CopyResult> results =
            CustomerPartNumberCopyAction.copyMappings(
                new List<CustomerPartNumberCopyAction.CopyRequest>{
                    buildRequest(east, mappingIds, new List<Id>{ stranger }, false)
                });
        Test.stopTest();

        Assert.areEqual(1, results[0].copied,
            'Targets outside the source account family must still copy');
        Assert.areEqual(0, results[0].failed);
        Assert.isTrue(String.isBlank(results[0].errorMessage));
    }

    @IsTest
    static void copy_topLevelSourceToOwnChild_createsCopiedRecords() {
        // The common case: source account IS the top-level parent, and the
        // target is one of its children (source has no ParentId of its own).
        Id stranger = accId('Stranger Co');
        Id strangerBranch = accId('Stranger Branch');
        List<Id> mappingIds = insertSourceMappings(stranger, 2);

        Test.startTest();
        List<CustomerPartNumberCopyAction.CopyResult> results =
            CustomerPartNumberCopyAction.copyMappings(
                new List<CustomerPartNumberCopyAction.CopyRequest>{
                    buildRequest(stranger, mappingIds,
                        new List<Id>{ strangerBranch }, false)
                });
        Test.stopTest();

        Assert.areEqual(2, results[0].copied,
            'A top-level source account must be able to copy to its own children');
        Assert.areEqual(0, results[0].failed);
        Assert.isTrue(String.isBlank(results[0].errorMessage));
    }

    @IsTest
    static void copy_toTargetWithFeatureDisabled_enablesFeatureFlag() {
        Id east = accId('Branch East');
        Id west = accId('Branch West');
        List<Id> mappingIds = insertSourceMappings(east, 1);

        Test.startTest();
        CustomerPartNumberCopyAction.copyMappings(
            new List<CustomerPartNumberCopyAction.CopyRequest>{
                buildRequest(east, mappingIds, new List<Id>{ west }, false)
            });
        Test.stopTest();

        Account target = [
            SELECT Enable_Customer_Part_Numbers__c FROM Account WHERE Id = :west
        ];
        Assert.isTrue(target.Enable_Customer_Part_Numbers__c,
            'A copy target must have the storefront display flag turned on');
    }

    @IsTest
    static void copy_sourceNotFound_returnsError() {
        List<Id> mappingIds = new List<Id>();

        List<CustomerPartNumberCopyAction.CopyResult> results =
            CustomerPartNumberCopyAction.copyMappings(
                new List<CustomerPartNumberCopyAction.CopyRequest>{
                    buildRequest(null, mappingIds,
                        new List<Id>{ accId('Branch West') }, false)
                });

        Assert.isTrue(String.isNotBlank(results[0].errorMessage),
            'A null/nonexistent source account must yield an error message');
    }
}