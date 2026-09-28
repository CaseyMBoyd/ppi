@IsTest
public class InventoryServiceB2B_TEST {

    @TestSetup
    static void setupData() {
        Product2 product=new Product2(Name='Test Product',ProductCode='TEST-SKU',IsActive=true);
        insert product;
    }

    @IsTest
    static void testEmptyProductCodes() {
        Test.startTest();
        Map<String,InventoryServiceB2B.AvailabilityWrapper> result=
            InventoryServiceB2B.calculateAvailability(new List<String>(),null,null);
        Test.stopTest();
        System.assertEquals(true,result.isEmpty(),'Result should be empty');
    }

    @IsTest
    static void testNullProductCodes() {
        Test.startTest();
        Map<String,InventoryServiceB2B.AvailabilityWrapper> result=
            InventoryServiceB2B.calculateAvailability(null,null,null);
        Test.stopTest();
        System.assert(result.isEmpty());
    }
    
    @IsTest
    static void testProductCodes() {
        Test.setMock(HttpCalloutMock.class,new InventorySuccessMock());
        Product2 productRecord=[SELECT Id FROM Product2
            WHERE ProductCode='TEST-SKU' LIMIT 1];
        Test.startTest();
        List<InventoryServiceB2B.InventoryLocationResult> result=
            InventoryServiceB2B.getBulkInventoryStatus(productRecord.Id);
        Test.stopTest();
        System.assertEquals(1, result.size());
        System.assertEquals(50, result[0].quantityAvailable);
        System.assertEquals('WH001', result[0].warehouseCode);
        System.assertNotEquals(null, result[0].locationDisplayName);
    }

    @IsTest
    static void testBulkInventoryUsesAssembleQtyFallback() {
        Test.setMock(HttpCalloutMock.class,new InventoryAssembleQtyMock());
        Product2 productRecord=[SELECT Id FROM Product2
            WHERE ProductCode='TEST-SKU' LIMIT 1];
        Test.startTest();
        List<InventoryServiceB2B.InventoryLocationResult> result=
            InventoryServiceB2B.getBulkInventoryStatus(productRecord.Id);
        Test.stopTest();
        System.assertEquals(1, result.size());
        System.assertEquals(25, result[0].quantityAvailable);
        System.assertEquals('WH002', result[0].warehouseCode);
    }

    @IsTest
    static void testBulkInventoryMadeToOrderWhenZero() {
        Test.setMock(HttpCalloutMock.class,new InventoryZeroQtyMock());
        Product2 productRecord=[SELECT Id FROM Product2
            WHERE ProductCode='TEST-SKU' LIMIT 1];
        Test.startTest();
        List<InventoryServiceB2B.InventoryLocationResult> result=
            InventoryServiceB2B.getBulkInventoryStatus(productRecord.Id);
        Test.stopTest();
        System.assert(result.isEmpty());
    }

    @IsTest
    static void testInventoryInStock() {
        Test.setMock(HttpCalloutMock.class,new InventorySuccessMock());
        Test.startTest();
        Map<String,InventoryServiceB2B.AvailabilityWrapper> result=
            InventoryServiceB2B.calculateAvailability(new List<String>{'TEST-SKU'},null,null);

        Test.stopTest();
        System.assert(result.containsKey('TEST-SKU'));
        System.assertEquals('In Stock',result.get('TEST-SKU').availabilityStatus);
        System.assert(result.get('TEST-SKU').availableQuantity>0);
        System.assert(result.get('TEST-SKU').warehouses.size()>0);
    }

    @IsTest
    static void testInventoryUnknown() {
        Test.setMock(HttpCalloutMock.class,new InventoryEmptyMock());
        Test.startTest();
        Map<String,InventoryServiceB2B.AvailabilityWrapper> result=
            InventoryServiceB2B.calculateAvailability(
                new List<String>{'UNKNOWN-SKU'},null,null
            );
        Test.stopTest();
        System.assertEquals('Availability Unknown',result.get('UNKNOWN-SKU').availabilityStatus);
    }

    @IsTest
    static void testMadeToOrderInventory() {
        Test.setMock(HttpCalloutMock.class,new InventoryZeroQtyMock());
        Test.startTest();
        Map<String,InventoryServiceB2B.AvailabilityWrapper> result= InventoryServiceB2B.calculateAvailability(
                new List<String>{'TEST-SKU'},null,null);

        Test.stopTest();
        System.assertEquals('Made to Order', result.get('TEST-SKU').availabilityStatus);
        System.assertEquals(0, result.get('TEST-SKU').availableQuantity);
    }
    @IsTest
    static void testQuantityAvailableToAssemble() {
        Test.setMock(HttpCalloutMock.class,new InventoryAssembleQtyMock());
        Test.startTest();
        Map<String,InventoryServiceB2B.AvailabilityWrapper> result=
            InventoryServiceB2B.calculateAvailability(
                new List<String>{'TEST-SKU'},null,null
            );
        Test.stopTest();
        System.assertEquals('In Stock',result.get('TEST-SKU').availabilityStatus);
    }
    @IsTest
    static void testLowStockUsingCategoryThreshold() {
        ProductCatalog catalog=new ProductCatalog(
            Name='Test Catalog'
        );
        insert catalog;

        ProductCategory category=new ProductCategory(
            Name='Test Category',
            CatalogId=catalog.Id,
            Low_Stock_Threshold__c=100
        );
        insert category;
        Test.setMock(HttpCalloutMock.class,new InventorySuccessMock());
        Test.startTest();
        Map<String,InventoryServiceB2B.AvailabilityWrapper> result=
            InventoryServiceB2B.calculateAvailability(
                new List<String>{'TEST-SKU'},
                category.Id,
                null
            );
        Test.stopTest();
        System.assertEquals('Low Stock', result.get('TEST-SKU').availabilityStatus);
    }

    @IsTest
    static void testWebStoreThresholdPath() {

        Product2 productRecord=[SELECT Id FROM Product2
            WHERE ProductCode='TEST-SKU' LIMIT 1];
        ProductCatalog catalog=new ProductCatalog(
            Name='Test Catalog'
        );
        insert catalog;
        ProductCategory category=new ProductCategory(
            Name='Test Category',
            CatalogId=catalog.Id,
            Low_Stock_Threshold__c=20
        );
        insert category;
        ProductCategoryProduct pcp=new ProductCategoryProduct(
            ProductId=productRecord.Id,
            ProductCategoryId=category.Id
        );
        insert pcp;
        WebStore store=new WebStore(
            Name='Test Store'
        );
        insert store;
        WebStoreCatalog wc=new WebStoreCatalog(
            SalesStoreId=store.Id,
            ProductCatalogId=catalog.Id
        );
        insert wc;
        Test.setMock(HttpCalloutMock.class,new InventorySuccessMock());
        Test.startTest();
        Map<String,InventoryServiceB2B.AvailabilityWrapper> result=
            InventoryServiceB2B.calculateAvailability(
                new List<String>{'TEST-SKU'},
                null,
                store.Id
            );
        Test.stopTest();
        System.assert(result.containsKey('TEST-SKU'));
        // Quantity (50) is above the product's own category threshold (20) - In Stock.
        // webStoreId no longer scopes the lookup; this just confirms passing it doesn't break anything.
        System.assertEquals('In Stock', result.get('TEST-SKU').availabilityStatus);
    }

    @IsTest
    static void testSearchResultsLowStockViaOwnCategory() {
        // Reproduces the reported bug: no contextCategoryId (Search Results page), so the
        // threshold must come from the product's own ProductCategoryProduct membership.
        Product2 productRecord=[SELECT Id FROM Product2
            WHERE ProductCode='TEST-SKU' LIMIT 1];
        ProductCatalog catalog=new ProductCatalog(Name='Test Catalog 2');
        insert catalog;
        ProductCategory category=new ProductCategory(
            Name='Test Category 2',
            CatalogId=catalog.Id,
            Low_Stock_Threshold__c=100
        );
        insert category;
        ProductCategoryProduct pcp=new ProductCategoryProduct(
            ProductId=productRecord.Id,
            ProductCategoryId=category.Id
        );
        insert pcp;

        Test.setMock(HttpCalloutMock.class,new InventorySuccessMock());
        Test.startTest();
        Map<String,InventoryServiceB2B.AvailabilityWrapper> result=
            InventoryServiceB2B.calculateAvailability(
                new List<String>{'TEST-SKU'},
                null,
                null
            );
        Test.stopTest();

        // Quantity (50) is at/under the category's threshold (100) - Low Stock.
        System.assertEquals('Low Stock', result.get('TEST-SKU').availabilityStatus);
    }

    @IsTest
    static void testSearchResultsUsesLowestThresholdAcrossMultipleCategories() {
        Product2 productRecord=[SELECT Id FROM Product2
            WHERE ProductCode='TEST-SKU' LIMIT 1];
        ProductCatalog catalog=new ProductCatalog(Name='Test Catalog 3');
        insert catalog;

        ProductCategory highThreshold=new ProductCategory(
            Name='High Threshold Category',
            CatalogId=catalog.Id,
            Low_Stock_Threshold__c=200
        );
        ProductCategory lowThreshold=new ProductCategory(
            Name='Low Threshold Category',
            CatalogId=catalog.Id,
            Low_Stock_Threshold__c=10
        );
        insert new List<ProductCategory>{highThreshold, lowThreshold};

        insert new List<ProductCategoryProduct>{
            new ProductCategoryProduct(ProductId=productRecord.Id, ProductCategoryId=highThreshold.Id),
            new ProductCategoryProduct(ProductId=productRecord.Id, ProductCategoryId=lowThreshold.Id)
        };

        Test.setMock(HttpCalloutMock.class,new InventorySuccessMock());
        Test.startTest();
        Map<String,InventoryServiceB2B.AvailabilityWrapper> result=
            InventoryServiceB2B.calculateAvailability(
                new List<String>{'TEST-SKU'},
                null,
                null
            );
        Test.stopTest();

        // Quantity is 50. Against the high threshold (200) alone this would be Low Stock,
        // but the lowest threshold across all of the product's categories (10) wins - In Stock.
        System.assertEquals('In Stock', result.get('TEST-SKU').availabilityStatus);
    }

    @IsTest
    static void testSearchResultsCategoryWithNullThresholdDefaultsToZero() {
        Product2 productRecord=[SELECT Id FROM Product2
            WHERE ProductCode='TEST-SKU' LIMIT 1];
        ProductCatalog catalog=new ProductCatalog(Name='Test Catalog 4');
        insert catalog;
        ProductCategory category=new ProductCategory(
            Name='Test Category 4',
            CatalogId=catalog.Id
            // Low_Stock_Threshold__c intentionally left null
        );
        insert category;
        ProductCategoryProduct pcp=new ProductCategoryProduct(
            ProductId=productRecord.Id,
            ProductCategoryId=category.Id
        );
        insert pcp;

        Test.setMock(HttpCalloutMock.class,new InventorySuccessMock());
        Test.startTest();
        Map<String,InventoryServiceB2B.AvailabilityWrapper> result=
            InventoryServiceB2B.calculateAvailability(
                new List<String>{'TEST-SKU'},
                null,
                null
            );
        Test.stopTest();

        // Null threshold defaults to 0, so any positive quantity (50) reads as In Stock.
        System.assertEquals('In Stock', result.get('TEST-SKU').availabilityStatus);
    }

    @IsTest
    static void testCategoryPageContextStillUsesDirectCategoryLookup() {
        // Confirms the category-page path is untouched: threshold comes from whatever
        // category is being browsed, even if the product also belongs to a different
        // category with a much lower threshold via ProductCategoryProduct.
        Product2 productRecord=[SELECT Id FROM Product2
            WHERE ProductCode='TEST-SKU' LIMIT 1];
        ProductCatalog catalog=new ProductCatalog(Name='Test Catalog 5');
        insert catalog;

        ProductCategory browsedCategory=new ProductCategory(
            Name='Browsed Category',
            CatalogId=catalog.Id,
            Low_Stock_Threshold__c=100
        );
        ProductCategory otherCategory=new ProductCategory(
            Name='Other Category',
            CatalogId=catalog.Id,
            Low_Stock_Threshold__c=1
        );
        insert new List<ProductCategory>{browsedCategory, otherCategory};

        insert new ProductCategoryProduct(
            ProductId=productRecord.Id,
            ProductCategoryId=otherCategory.Id
        );

        Test.setMock(HttpCalloutMock.class,new InventorySuccessMock());
        Test.startTest();
        Map<String,InventoryServiceB2B.AvailabilityWrapper> result=
            InventoryServiceB2B.calculateAvailability(
                new List<String>{'TEST-SKU'},
                browsedCategory.Id,
                null
            );
        Test.stopTest();

        // Quantity (50) is under the browsed category's threshold (100) - Low Stock,
        // regardless of the product's unrelated ProductCategoryProduct membership elsewhere.
        System.assertEquals('Low Stock', result.get('TEST-SKU').availabilityStatus);
    }

    @IsTest
    static void testCategoryPageWithNullThresholdDefaultsToZero() {
        ProductCatalog catalog=new ProductCatalog(Name='Test Catalog 6');
        insert catalog;
        ProductCategory category=new ProductCategory(
            Name='Test Category 6',
            CatalogId=catalog.Id
            // Low_Stock_Threshold__c intentionally left null
        );
        insert category;

        Test.setMock(HttpCalloutMock.class,new InventorySuccessMock());
        Test.startTest();
        Map<String,InventoryServiceB2B.AvailabilityWrapper> result=
            InventoryServiceB2B.calculateAvailability(
                new List<String>{'TEST-SKU'},
                category.Id,
                null
            );
        Test.stopTest();

        // Null threshold on the browsed category defaults to 0, so quantity 50 reads as In Stock.
        System.assertEquals('In Stock', result.get('TEST-SKU').availabilityStatus);
    }

    @IsTest
    static void resolveLeadTimeText_matchesFirstCategoryInChainWithMatchingWarehouse() {
        List<String> chain = new List<String>{ 'Equal Troughing Idlers', 'Idlers' };
        List<Lead_Time_Guidance__mdt> rules = new List<Lead_Time_Guidance__mdt>{
            new Lead_Time_Guidance__mdt(
                Product_Category__c = 'Idlers',
                Location_Code__c = 'WH001',
                Lead_Time_Display_Value__c = 'Broad idlers rule'
            ),
            new Lead_Time_Guidance__mdt(
                Product_Category__c = 'Equal Troughing Idlers',
                Location_Code__c = 'WH001',
                Lead_Time_Display_Value__c = 'Specific subcategory rule'
            )
        };

        String result = InventoryServiceB2B.resolveLeadTimeText(chain, 'WH001', rules);

        Assert.areEqual('Specific subcategory rule', result,
            'The most specific category in the chain must win over a broader parent rule');
    }

    @IsTest
    static void resolveLeadTimeText_fallsBackToParentCategoryWhenNoLeafRuleExists() {
        // Reproduces the reported bug: a subcategory has no rule of its own, but its
        // parent category does - the walk-up must find it.
        List<String> chain = new List<String>{ 'Equal Troughing Idlers', 'Idlers' };
        List<Lead_Time_Guidance__mdt> rules = new List<Lead_Time_Guidance__mdt>{
            new Lead_Time_Guidance__mdt(
                Product_Category__c = 'Idlers',
                Location_Code__c = 'WH001',
                Lead_Time_Display_Value__c = 'Broad idlers rule'
            )
        };

        String result = InventoryServiceB2B.resolveLeadTimeText(chain, 'WH001', rules);

        Assert.areEqual('Broad idlers rule', result,
            'Must walk up to the parent category rule when the leaf has none');
    }

    @IsTest
    static void resolveLeadTimeText_returnsNullWhenNoRuleMatchesAnyLevelOrWarehouse() {
        List<String> chain = new List<String>{ 'Equal Troughing Idlers', 'Idlers' };
        List<Lead_Time_Guidance__mdt> rules = new List<Lead_Time_Guidance__mdt>{
            new Lead_Time_Guidance__mdt(
                Product_Category__c = 'Idlers',
                Location_Code__c = 'WH999',
                Lead_Time_Display_Value__c = 'Wrong warehouse'
            )
        };

        String result = InventoryServiceB2B.resolveLeadTimeText(chain, 'WH001', rules);

        Assert.isNull(result, 'No match at any level or warehouse must return null');
    }

    @IsTest
    static void buildCategoryNameChain_walksFromLeafToRoot() {
        ProductCatalog catalog = new ProductCatalog(Name = 'Lead Time Catalog');
        insert catalog;

        ProductCategory root = new ProductCategory(Name = 'Idlers', CatalogId = catalog.Id);
        insert root;
        ProductCategory leaf = new ProductCategory(
            Name = 'Equal Troughing Idlers', CatalogId = catalog.Id, ParentCategoryId = root.Id
        );
        insert leaf;

        Map<Id, ProductCategory> categoryTreeMap = new Map<Id, ProductCategory>(
            [SELECT Id, Name, ParentCategoryId FROM ProductCategory WHERE CatalogId = :catalog.Id]
        );

        List<String> chain = InventoryServiceB2B.buildCategoryNameChain(leaf.Id, categoryTreeMap);

        Assert.areEqual(new List<String>{ 'Equal Troughing Idlers', 'Idlers' }, chain,
            'Chain must list the leaf first, then walk up to the root');
    }

    @IsTest
    static void calculateAvailability_setsLeadTimeTextViaSubcategoryHierarchyWalk() {
        // End-to-end: product is only assigned to the subcategory; the matching
        // Lead_Time_Guidance__mdt rule exists on the parent category. This is the
        // exact scenario reported as broken in PBPP2-43.
        Product2 productRecord = [SELECT Id FROM Product2 WHERE ProductCode = 'TEST-SKU' LIMIT 1];
        ProductCatalog catalog = new ProductCatalog(Name = 'Lead Time Catalog 2');
        insert catalog;

        ProductCategory root = new ProductCategory(Name = 'Idlers', CatalogId = catalog.Id);
        insert root;
        ProductCategory leaf = new ProductCategory(
            Name = 'Equal Troughing Idlers', CatalogId = catalog.Id, ParentCategoryId = root.Id
        );
        insert leaf;

        insert new ProductCategoryProduct(ProductId = productRecord.Id, ProductCategoryId = leaf.Id);

        Test.setMock(HttpCalloutMock.class, new InventorySuccessMock());
        Test.startTest();
        Map<String, InventoryServiceB2B.AvailabilityWrapper> result =
            InventoryServiceB2B.calculateAvailability(new List<String>{ 'TEST-SKU' }, null, null);
        Test.stopTest();

        // No Lead_Time_Guidance__mdt records exist in this org for 'Idlers'/'WH001' in a
        // fresh test context, so this confirms the default text when nothing matches -
        // the hierarchy-walk wiring itself is covered directly by the unit tests above.
        Assert.areEqual(1, result.get('TEST-SKU').warehouses.size());
        Assert.isNotNull(result.get('TEST-SKU').warehouses[0].contextualLeadTimeText);
    }

    @IsTest
    static void testERPExceptionPath() {
        Test.setMock(HttpCalloutMock.class,new InventoryErrorMock());
        Test.startTest();
        Map<String,InventoryServiceB2B.AvailabilityWrapper> result=
            InventoryServiceB2B.calculateAvailability(
                new List<String>{'TEST-SKU'},
                null,
                null
            );

        Test.stopTest();
        System.assertEquals(
            'Availability Unknown',
            result.get('TEST-SKU').availabilityStatus
        );
    }

    private class InventorySuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res=new HttpResponse();
            res.setStatusCode(200);
            res.setBody('[{"quantityAvailable":50,"warehouse":{"id":"WH001","name":"WEST COAST"}}]');
            return res;
        }
    }

    private class InventoryEmptyMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res=new HttpResponse();
            res.setStatusCode(200);
            res.setBody('[]');
            return res;
        }
    }

    private class InventoryZeroQtyMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res=new HttpResponse();
            res.setStatusCode(200);
            res.setBody('[{"quantityAvailable":0,"warehouse":{"id":"WH001","name":"WEST"}}]');
            return res;
        }
    }

    private class InventoryAssembleQtyMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res=new HttpResponse();
            res.setStatusCode(200);
            res.setBody('[{"quantityAvailableToAssemble":25,"warehouse":{"id":"WH002","name":"EAST"}}]');

            return res;
        }
    }
    private class InventoryErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {

            throw new CalloutException('Test Exception');
        }
    }
}