/**
 * @description Tests for CustomerProductMappingTrigger, Handler and Queueable.
 */
@IsTest
private class CustomerProductMappingHandlerTest {

    private static final String VALID_SKU = 'TST-VALID-001';
    private static final String INVALID_SKU = 'TST-NOPE-999';

    @TestSetup
    static void setup() {
        // Create the Support Request queue only if it does not already exist in the org.
        // Many sandboxes already have it (with assignment rules linked); recreating it
        // would either fail or leave the @TestSetup partially executed.
        List<Group> existing = [
            SELECT Id FROM Group
            WHERE Name = 'Support Request' AND Type = 'Queue' LIMIT 1
        ];
        if (existing.isEmpty()) {
            System.runAs(new User(Id = UserInfo.getUserId())) {
                Group supportQueue = new Group(
                    Name = 'Support Request', Type = 'Queue');
                insert supportQueue;
                insert new QueueSobject(
                    QueueId = supportQueue.Id, SobjectType = 'Case');
            }
        }

        insert new Account(Name = 'CPM Test Account');
        insert new Product2(
            Name = 'Valid Test Product',
            StockKeepingUnit = VALID_SKU,
            IsActive = true
        );
    }

    private static void overrideSkuResolution() {
        Id productId = [SELECT Id FROM Product2 WHERE StockKeepingUnit = :VALID_SKU LIMIT 1].Id;
        CustomerProductMappingQueueable.skuResolutionOverrideForTests =
            new Map<String, Id>{ VALID_SKU => productId };
    }

    @IsTest
    static void insertValidSku_validatesAndActivates() {
        overrideSkuResolution();
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        insert new Customer_Product_Mapping__c(
            Account__c = acc.Id,
            Customer_Part_Number__c = 'CUST-001',
            PPI_SKU_Input__c = VALID_SKU
        );
        Test.stopTest();

        Customer_Product_Mapping__c result = [
            SELECT Validation_Status__c, Is_Active__c, Product__c,
                   Mapping_Composite_Key__c
            FROM Customer_Product_Mapping__c LIMIT 1
        ];
        Assert.areEqual('Valid', result.Validation_Status__c,
            'SKU matching an active product must be Valid');
        Assert.isTrue(result.Is_Active__c, 'Valid mapping must be active');
        Assert.isNotNull(result.Product__c, 'Product lookup must be resolved');
        Assert.areEqual(String.valueOf(acc.Id) + '_CUST-001',
            result.Mapping_Composite_Key__c, 'Composite key must be stamped');
    }

    @IsTest
    static void insertInvalidSku_marksInvalidAndCreatesCase() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        insert new Customer_Product_Mapping__c(
            Account__c = acc.Id,
            Customer_Part_Number__c = 'CUST-002',
            PPI_SKU_Input__c = INVALID_SKU
        );
        Test.stopTest();

        Customer_Product_Mapping__c result = [
            SELECT Validation_Status__c, Is_Active__c, Product__c
            FROM Customer_Product_Mapping__c LIMIT 1
        ];
        Assert.areEqual('Invalid', result.Validation_Status__c,
            'Unknown SKU must be Invalid');
        Assert.isFalse(result.Is_Active__c, 'Invalid mapping must stay inactive');
        Assert.isNull(result.Product__c, 'Invalid mapping must not link a product');

        List<Case> cases = [
            SELECT Id FROM Case
            WHERE Subject = 'Customer Part Number Upload - Validation Error'
        ];
        Assert.areEqual(1, cases.size(),
            'A Case must be created in the Support Request queue');
    }

    @IsTest
    static void updateSkuChange_revalidates() {
        overrideSkuResolution();
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Customer_Product_Mapping__c mapping = new Customer_Product_Mapping__c(
            Account__c = acc.Id,
            Customer_Part_Number__c = 'CUST-003',
            PPI_SKU_Input__c = INVALID_SKU
        );
        insert mapping;

        Test.startTest();
        mapping.PPI_SKU_Input__c = VALID_SKU;
        update mapping;
        Test.stopTest();

        Customer_Product_Mapping__c result = [
            SELECT Validation_Status__c, Is_Active__c
            FROM Customer_Product_Mapping__c WHERE Id = :mapping.Id
        ];
        Assert.areEqual('Valid', result.Validation_Status__c,
            'Changing to a valid SKU must re-validate to Valid');
        Assert.isTrue(result.Is_Active__c, 'Re-validated mapping must activate');
    }

    @IsTest
    static void updatePartNumber_restampsCompositeKey() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Customer_Product_Mapping__c mapping = new Customer_Product_Mapping__c(
            Account__c = acc.Id,
            Customer_Part_Number__c = 'CUST-OLD',
            PPI_SKU_Input__c = VALID_SKU
        );
        insert mapping;

        mapping.Customer_Part_Number__c = 'CUST-NEW';
        update mapping;

        Customer_Product_Mapping__c result = [
            SELECT Mapping_Composite_Key__c
            FROM Customer_Product_Mapping__c WHERE Id = :mapping.Id
        ];
        Assert.areEqual(String.valueOf(acc.Id) + '_CUST-NEW',
            result.Mapping_Composite_Key__c,
            'Composite key must follow the renamed part number');
    }

    @IsTest
    static void bulkInsert_processesAllRecords() {
        overrideSkuResolution();
        Account acc = [SELECT Id FROM Account LIMIT 1];
        List<Customer_Product_Mapping__c> bulkRecords =
            new List<Customer_Product_Mapping__c>();
        for (Integer i = 0; i < 200; i++) {
            bulkRecords.add(new Customer_Product_Mapping__c(
                Account__c = acc.Id,
                Customer_Part_Number__c = 'BULK-' + i,
                PPI_SKU_Input__c = VALID_SKU
            ));
        }

        Test.startTest();
        insert bulkRecords;
        Test.stopTest();

        Integer validCount = [
            SELECT COUNT() FROM Customer_Product_Mapping__c
            WHERE Validation_Status__c = 'Valid' AND Is_Active__c = true
        ];
        Assert.areEqual(200, validCount,
            'All bulk records must be validated in a single async pass');
    }

    @IsTest
    static void createErrorCase_withEmptyList_createsGenericCase() {
        Test.startTest();
        // Exercises the finalizer path: empty list -> generic description
        CustomerProductMappingQueueable.createErrorCase(
            new List<Customer_Product_Mapping__c>());
        Test.stopTest();

        List<Case> cases = [
            SELECT Description FROM Case
            WHERE Subject = 'Customer Part Number Upload - Validation Error'
        ];
        Assert.areEqual(1, cases.size(),
            'A Case is created with a generic description on job-level failure');
        Assert.isTrue(cases[0].Description.contains('unexpected error'),
            'Generic description must indicate an unexpected error');
    }
}