/**
 * @description Tests for CustomerPartNumberController + duplicate enforcement
 * in CustomerProductMappingHandler (trigger-level addError).
 */
@IsTest
private class CustomerPartNumberControllerTest {

    private static final String VALID_SKU = 'CTL-VALID-001';
    private static final String DUPLICATE_FRAGMENT = 'already mapped on this account';

    @TestSetup
    static void setup() {
        insert new Account(
            Name = 'Enabled Account',
            Enable_Customer_Part_Numbers__c = true
        );
        insert new Account(
            Name = 'Disabled Account',
            Enable_Customer_Part_Numbers__c = false
        );
        insert new Product2(
            Name = 'Controller Test Product',
            StockKeepingUnit = VALID_SKU,
            IsActive = true
        );
    }

    private static Id enabledAccountId() {
        return [SELECT Id FROM Account WHERE Name = 'Enabled Account'].Id;
    }
    private static Id disabledAccountId() {
        return [SELECT Id FROM Account WHERE Name = 'Disabled Account'].Id;
    }

    private static void overrideSkuResolution() {
        Id productId = [SELECT Id FROM Product2 WHERE StockKeepingUnit = :VALID_SKU LIMIT 1].Id;
        CustomerProductMappingQueueable.skuResolutionOverrideForTests =
            new Map<String, Id>{ VALID_SKU => productId };
    }

    private static Customer_Product_Mapping__c insertActiveMapping(Id accId) {
        overrideSkuResolution();
        Customer_Product_Mapping__c m = new Customer_Product_Mapping__c(
            Account__c = accId,
            Customer_Part_Number__c = 'MY-PART-1',
            PPI_SKU_Input__c = VALID_SKU
        );
        Test.startTest();
        insert m;
        Test.stopTest(); // queueable validates and activates
        return m;
    }

    @IsTest
    static void isFeatureEnabled_respectsToggleAndNull() {
        Assert.isTrue(CustomerPartNumberController.isFeatureEnabled(enabledAccountId()));
        Assert.isFalse(CustomerPartNumberController.isFeatureEnabled(disabledAccountId()));
        Assert.isFalse(CustomerPartNumberController.isFeatureEnabled(null));
    }

    @IsTest
    static void getMappings_returnsOnlyWhenEnabled() {
        Id accId = enabledAccountId();
        insertActiveMapping(accId);

        List<Customer_Product_Mapping__c> mappings =
            CustomerPartNumberController.getMappings(accId);
        Assert.areEqual(1, mappings.size());

        Assert.areEqual(0,
            CustomerPartNumberController.getMappings(disabledAccountId()).size(),
            'Disabled account must return no mappings');
    }

    @IsTest
    static void translateToProductSku_translatesActiveMapping() {
        Id accId = enabledAccountId();
        insertActiveMapping(accId);

        Assert.areEqual(VALID_SKU,
            CustomerPartNumberController.translateToProductSku('MY-PART-1', accId));
        Assert.isNull(
            CustomerPartNumberController.translateToProductSku('UNKNOWN', accId));
        Assert.isNull(
            CustomerPartNumberController.translateToProductSku('MY-PART-1', null));
    }

    @IsTest
    static void getCustomerPartNumberForProduct_resolvesAndRespectsToggle() {
        Id accId = enabledAccountId();
        insertActiveMapping(accId);
        Id productId = [SELECT Id FROM Product2 WHERE StockKeepingUnit = :VALID_SKU].Id;

        Assert.areEqual('MY-PART-1',
            CustomerPartNumberController.getCustomerPartNumberForProduct(productId, accId));
        Assert.isNull(
            CustomerPartNumberController.getCustomerPartNumberForProduct(
                productId, disabledAccountId()),
            'Toggle off must hide the part number');
        Assert.isNull(
            CustomerPartNumberController.getCustomerPartNumberForProduct(null, accId));
    }

    @IsTest
    static void saveMapping_insertAndUpdate() {
        Id accId = enabledAccountId();

        Customer_Product_Mapping__c rec = new Customer_Product_Mapping__c(
            Account__c = accId,
            Customer_Part_Number__c = 'SAVE-1',
            PPI_SKU_Input__c = VALID_SKU
        );
        Test.startTest();
        CustomerPartNumberController.saveMapping(rec);
        Test.stopTest();

        Customer_Product_Mapping__c saved = [
            SELECT Id, Source_Type__c, Mapping_Composite_Key__c
            FROM Customer_Product_Mapping__c WHERE Customer_Part_Number__c = 'SAVE-1'
        ];
        Assert.areEqual('Portal', saved.Source_Type__c,
            'Blank source type must default to Portal');
        Assert.areEqual(String.valueOf(accId) + '_SAVE-1',
            saved.Mapping_Composite_Key__c);

        saved.Customer_Part_Number__c = 'SAVE-2';
        CustomerPartNumberController.saveMapping(saved);
        Assert.areEqual(1, [
            SELECT COUNT() FROM Customer_Product_Mapping__c
            WHERE Customer_Part_Number__c = 'SAVE-2'
        ]);
    }

    @IsTest
    static void saveMapping_withoutAccount_throws() {
        try {
            CustomerPartNumberController.saveMapping(
                new Customer_Product_Mapping__c(Customer_Part_Number__c = 'X'));
            Assert.fail('Missing account must throw');
        } catch (AuraHandledException e) {
            Assert.isTrue(true);
        }
    }

    @IsTest
    static void saveMapping_duplicate_surfacesFriendlyMessage() {
        Id accId = enabledAccountId();
        overrideSkuResolution();

        // First mapping succeeds and stamps the unique composite key.
        Customer_Product_Mapping__c first = new Customer_Product_Mapping__c(
            Account__c = accId,
            Customer_Part_Number__c = 'DUP-1',
            PPI_SKU_Input__c = VALID_SKU
        );

        Test.startTest();
        CustomerPartNumberController.saveMapping(first);

        // Second mapping with the same Account + Customer Part Number is blocked by
        // the trigger; the controller surfaces the friendly message to the LWC.
        String thrownMessage;
        try {
            CustomerPartNumberController.saveMapping(new Customer_Product_Mapping__c(
                Account__c = accId,
                Customer_Part_Number__c = 'DUP-1',
                PPI_SKU_Input__c = VALID_SKU
            ));
            Assert.fail('Duplicate Customer Part Number must throw');
        } catch (AuraHandledException e) {
            thrownMessage = e.getMessage();
        }
        Test.stopTest();

        Assert.isTrue(
            thrownMessage != null && thrownMessage.contains(DUPLICATE_FRAGMENT),
            'Duplicate save should surface the friendly message. Got: ' + thrownMessage);

        // Only the original record should exist.
        Assert.areEqual(1, [
            SELECT COUNT() FROM Customer_Product_Mapping__c
            WHERE Customer_Part_Number__c = 'DUP-1'
        ]);
    }

    @IsTest
    static void directInsert_duplicate_blockedWithFriendlyMessage() {
        // Simulates the admin native modal / Data Loader path (no controller),
        // which is blocked by the trigger before the Unique field's raw error.
        Id accId = enabledAccountId();
        overrideSkuResolution();

        Test.startTest();
        insert new Customer_Product_Mapping__c(
            Account__c = accId,
            Customer_Part_Number__c = 'DIRECT-1',
            PPI_SKU_Input__c = VALID_SKU
        );

        String msg;
        try {
            insert new Customer_Product_Mapping__c(
                Account__c = accId,
                Customer_Part_Number__c = 'DIRECT-1',
                PPI_SKU_Input__c = VALID_SKU
            );
            Assert.fail('Duplicate direct insert must be blocked by the trigger');
        } catch (DmlException e) {
            msg = e.getDmlMessage(0);
        }
        Test.stopTest();

        Assert.isTrue(msg != null && msg.contains(DUPLICATE_FRAGMENT),
            'Trigger should block the duplicate with the friendly message. Got: ' + msg);
        Assert.areEqual(1, [
            SELECT COUNT() FROM Customer_Product_Mapping__c
            WHERE Customer_Part_Number__c = 'DIRECT-1'
        ]);
    }

    @IsTest
    static void deleteMapping_removesVisibleRecord() {
        Id accId = enabledAccountId();
        Customer_Product_Mapping__c m = insertActiveMapping(accId);

        CustomerPartNumberController.deleteMapping(m.Id);
        Assert.areEqual(0, [SELECT COUNT() FROM Customer_Product_Mapping__c]);

        // Null and unknown ids are no-ops
        CustomerPartNumberController.deleteMapping(null);
    }

    @IsTest
    static void processCsvUpload_upsertsAndQueuesValidation() {
        Id accId = enabledAccountId();
        String csv = 'Customer_Part_Number,PPI_Part_Number\n'
            + 'CSV-1,' + VALID_SKU + '\n'
            + 'CSV-2,BAD-SKU\n';
        String csvBase64 = EncodingUtil.base64Encode(Blob.valueOf(csv));
        overrideSkuResolution();

        Test.startTest();
        CustomerPartNumberController.processCsvUpload(csvBase64, accId);
        Test.stopTest();

        Map<String, Customer_Product_Mapping__c> byPart =
            new Map<String, Customer_Product_Mapping__c>();
        for (Customer_Product_Mapping__c m : [
            SELECT Customer_Part_Number__c, Validation_Status__c, Is_Active__c
            FROM Customer_Product_Mapping__c
        ]) {
            byPart.put(m.Customer_Part_Number__c, m);
        }
        Assert.areEqual(2, byPart.size());
        Assert.areEqual('Valid', byPart.get('CSV-1').Validation_Status__c);
        Assert.areEqual('Invalid', byPart.get('CSV-2').Validation_Status__c);
    }

    @IsTest
    static void processCsvUpload_disabledAccountOrBlank_throws() {
        try {
            CustomerPartNumberController.processCsvUpload(
                EncodingUtil.base64Encode(Blob.valueOf('a,b')),
                disabledAccountId());
            Assert.fail('Disabled account must throw');
        } catch (AuraHandledException e) {
            Assert.isTrue(true);
        }
        try {
            CustomerPartNumberController.processCsvUpload(null, enabledAccountId());
            Assert.fail('Blank content must throw');
        } catch (AuraHandledException e) {
            Assert.isTrue(true);
        }
    }
}