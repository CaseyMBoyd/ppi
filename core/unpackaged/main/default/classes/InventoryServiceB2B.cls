public without sharing class InventoryServiceB2B {
    
    public class AvailabilityWrapper {
        @AuraEnabled public String availabilityStatus;
        @AuraEnabled public Integer availableQuantity;
        @AuraEnabled public List<WarehouseWrapper> warehouses;
    }
    public class WarehouseWrapper {
        @AuraEnabled public String warehouseName;
        @AuraEnabled public String warehouseCode; //4419
        @AuraEnabled public Integer quantity;
        @AuraEnabled public String contextualLeadTimeText;
    }
    
    public static Map<String, AvailabilityWrapper> calculateAvailability(List<String> productCodes, Id contextCategoryId, Id webStoreId) {
        
        Map<String, AvailabilityWrapper> results = new Map<String, AvailabilityWrapper>();
        
        if (productCodes == null || productCodes.isEmpty()) {
            return results;
        }

        // Lead time guidance is matched purely on category (any level, via hierarchy
        // walk) + warehouse - mirrors how buildThresholdMap() resolves category for
        // stock status, so both features behave consistently. No quantity involved.
        Map<String, List<String>> skuToCategoryChainMap =
            buildLeadTimeCategoryChains(productCodes, contextCategoryId);
        List<Lead_Time_Guidance__mdt> leadTimeRules = LeadTimeMetadataControllerB2B.getLeadTimeGuidanceRules();

        // Phase 1: Build SKU → threshold map
        Map<String, Decimal> skuToThresholdMap =
            buildThresholdMap(productCodes, contextCategoryId);
        
        // Phase 2: Process ERP inventory for all products
        for (String sku : productCodes) {
            
            List<ExternalService.XaApiService_getItemInventoryByItemNumber_OUT_200> erpData = fetchErpInventory(sku);
            if (erpData == null || erpData.isEmpty()) {
                
                AvailabilityWrapper wrapper = new AvailabilityWrapper();
                wrapper.availabilityStatus = 'Availability Unknown';
                
                results.put(sku, wrapper);
                continue;
            }
            /*
* Collect ERP warehouse names
* and translate using InventoryLocationTransformer
*/
            Set<String> erpWarehouseNames = new Set<String>();
            for (ExternalService.XaApiService_getItemInventoryByItemNumber_OUT_200 erpItem : erpData) {
                
                if (erpItem.warehouse != null && erpItem.warehouse.id != null) {
                    erpWarehouseNames.add(erpItem.warehouse.id);
                }
            }
            Map<String,String> warehouseNameMap = InventoryLocationTransformer.getFriendlyLocationNamesBulk(erpWarehouseNames);
            
            Integer totalQuantity = 0;
            List<WarehouseWrapper> warehouseList = new List<WarehouseWrapper>();
            
            // Phase 3: Aggregate inventory across service centers
            for (ExternalService.XaApiService_getItemInventoryByItemNumber_OUT_200 erpItem : erpData) {
                Integer quantity = 0;
                
                if (erpItem.quantityAvailable != null) {
                    quantity =Integer.valueOf(erpItem.quantityAvailable);
                    
                } else if (erpItem.quantityAvailableToAssemble != null) {
                    quantity =Integer.valueOf(erpItem.quantityAvailableToAssemble);
                }
                totalQuantity += quantity;
                
                if (quantity > 0 && erpItem.warehouse != null) {
                    WarehouseWrapper warehouse =new WarehouseWrapper();
                    String erpWarehouseId =erpItem.warehouse.id;
                    warehouse.warehouseName =
                        warehouseNameMap.containsKey(erpWarehouseId)
                        ? warehouseNameMap.get(erpWarehouseId)
                        : erpItem.warehouse.name;
                    warehouse.warehouseCode = erpWarehouseId;  //4419
                    warehouse.quantity = quantity;

                    List<String> categoryChain = skuToCategoryChainMap.containsKey(sku)
                        ? skuToCategoryChainMap.get(sku)
                        : new List<String>();
                    String matchedLeadTimeText =
                        resolveLeadTimeText(categoryChain, erpWarehouseId, leadTimeRules);
                    warehouse.contextualLeadTimeText = matchedLeadTimeText != null
                        ? matchedLeadTimeText
                        : 'Lead time information not available';

                    warehouseList.add(warehouse);
                }
            }
            AvailabilityWrapper wrapper = new AvailabilityWrapper();
            
            Decimal threshold = skuToThresholdMap.containsKey(sku) ? skuToThresholdMap.get(sku) : 0;
            if (totalQuantity == 0) {
                wrapper.availabilityStatus ='Made to Order';
            } else if (totalQuantity <= threshold) {
                wrapper.availabilityStatus ='Low Stock';
            } else {
                wrapper.availabilityStatus ='In Stock';
            }
            wrapper.availableQuantity =
                totalQuantity;
            
            wrapper.warehouses =
                warehouseList;
            
            
            results.put(
                sku,
                wrapper
            );
        }
        
        
        return results;
    }
    
    @TestVisible
    private static Map<String, Decimal> buildThresholdMap(List<String> productCodes, Id contextCategoryId) {
        Map<String, Decimal> skuToThresholdMap = new Map<String, Decimal>();

        if (contextCategoryId != null) {
            // Category page: threshold is whatever category is currently being browsed. Unchanged from before.
            // WITH SYSTEM_MODE - inventory threshold lookups aren't buyer-sensitive data and shouldn't
            // depend on the running user's sharing access to ProductCategory/ProductCategoryProduct.
            List<ProductCategory> categoryList = [SELECT Low_Stock_Threshold__c FROM ProductCategory
                                                  WHERE Id = :contextCategoryId WITH SYSTEM_MODE LIMIT 1];

            Decimal threshold = (!categoryList.isEmpty() && categoryList[0].Low_Stock_Threshold__c != null)
                ? categoryList[0].Low_Stock_Threshold__c
                : 0;

            for (String sku : productCodes) {
                skuToThresholdMap.put(sku, threshold);
            }

            return skuToThresholdMap;
        }

        // No category in view (e.g. Search Results): resolve each product's threshold from its
        // own ProductCategoryProduct membership instead. Not scoped to a webstore/catalog - that
        // scoping was filtering out the correct category even when the product's data was correct.
        Map<Id, String> productIdToSkuMap = new Map<Id, String>();
        for (Product2 productRecord : [SELECT Id, ProductCode FROM Product2 WHERE ProductCode IN :productCodes WITH SYSTEM_MODE]) {
            productIdToSkuMap.put(productRecord.Id, productRecord.ProductCode);
        }

        if (productIdToSkuMap.isEmpty()) {
            return skuToThresholdMap;
        }

        for (ProductCategoryProduct categoryProduct : [
            SELECT ProductId, ProductCategory.Low_Stock_Threshold__c
            FROM ProductCategoryProduct
            WHERE ProductId IN :productIdToSkuMap.keySet()
            WITH SYSTEM_MODE
        ]) {
            String sku = productIdToSkuMap.get(categoryProduct.ProductId);

            if (sku == null) {
                continue;
            }

            Decimal threshold = categoryProduct.ProductCategory.Low_Stock_Threshold__c != null
                ? categoryProduct.ProductCategory.Low_Stock_Threshold__c
                : 0;

            if (!skuToThresholdMap.containsKey(sku) || threshold < skuToThresholdMap.get(sku)) {
                skuToThresholdMap.put(sku, threshold);
            }
        }

        return skuToThresholdMap;
    }

    // Resolves each SKU's category chain (most specific first, walking up through
    // parent categories) for lead time matching. Mirrors buildThresholdMap()'s
    // contextCategoryId/ProductCategoryProduct resolution so both features stay
    // consistent, but returns full ancestor chains instead of a single value since
    // Lead_Time_Guidance__mdt rules can be authored at any level of the tree.
    @TestVisible
    private static Map<String, List<String>> buildLeadTimeCategoryChains(
        List<String> productCodes, Id contextCategoryId
    ) {
        Map<String, List<String>> skuToCategoryChain = new Map<String, List<String>>();

        // Bulk-fetch the full category tree (Id, Name, ParentCategoryId) once so the
        // hierarchy walk below stays entirely in-memory - no per-SKU or per-level SOQL.
        Map<Id, ProductCategory> categoryTreeMap = new Map<Id, ProductCategory>(
            [SELECT Id, Name, ParentCategoryId FROM ProductCategory WITH SYSTEM_MODE]
        );

        if (contextCategoryId != null) {
            List<String> chain = buildCategoryNameChain(contextCategoryId, categoryTreeMap);
            for (String sku : productCodes) {
                skuToCategoryChain.put(sku, chain);
            }
            return skuToCategoryChain;
        }

        Map<Id, String> productIdToSkuMap = new Map<Id, String>();
        for (Product2 productRecord : [SELECT Id, ProductCode FROM Product2 WHERE ProductCode IN :productCodes WITH SYSTEM_MODE]) {
            productIdToSkuMap.put(productRecord.Id, productRecord.ProductCode);
        }

        if (productIdToSkuMap.isEmpty()) {
            return skuToCategoryChain;
        }

        for (ProductCategoryProduct categoryProduct : [
            SELECT ProductId, ProductCategoryId
            FROM ProductCategoryProduct
            WHERE ProductId IN :productIdToSkuMap.keySet()
            WITH SYSTEM_MODE
        ]) {
            String sku = productIdToSkuMap.get(categoryProduct.ProductId);
            if (sku == null) {
                continue;
            }
            if (!skuToCategoryChain.containsKey(sku)) {
                skuToCategoryChain.put(sku, new List<String>());
            }
            skuToCategoryChain.get(sku)
                .addAll(buildCategoryNameChain(categoryProduct.ProductCategoryId, categoryTreeMap));
        }

        return skuToCategoryChain;
    }

    @TestVisible
    private static List<String> buildCategoryNameChain(Id leafCategoryId, Map<Id, ProductCategory> categoryTreeMap) {
        List<String> chain = new List<String>();
        Id currentId = leafCategoryId;
        Integer levelsWalked = 0;
        // Guards against a malformed/cyclical tree; real category hierarchies are shallow.
        while (currentId != null && levelsWalked < 20) {
            ProductCategory category = categoryTreeMap.get(currentId);
            if (category == null) {
                break;
            }
            chain.add(category.Name);
            currentId = category.ParentCategoryId;
            levelsWalked++;
        }
        return chain;
    }

    @TestVisible
    private static String resolveLeadTimeText(
        List<String> categoryNamesMostSpecificFirst, String warehouseId, List<Lead_Time_Guidance__mdt> rules
    ) {
        for (String categoryName : categoryNamesMostSpecificFirst) {
            for (Lead_Time_Guidance__mdt rule : rules) {
                if (rule.Product_Category__c == categoryName && rule.Location_Code__c == warehouseId) {
                    return rule.Lead_Time_Display_Value__c;
                }
            }
        }
        return null;
    }

    @TestVisible
    private static List<ExternalService.XaApiService_getItemInventoryByItemNumber_OUT_200> fetchErpInventory(String productCode) {
        
        try {
            ExternalService.XaApiService service = new ExternalService.XaApiService();
            
            ExternalService.XaApiService.getItemInventoryByItemNumber_Request request =
                new ExternalService.XaApiService.getItemInventoryByItemNumber_Request();
            
            request.itemNumber = productCode;
            
            ExternalService.XaApiService.getItemInventoryByItemNumber_Response response =
                service.getItemInventoryByItemNumber(request);
            
            if (response != null && response.Code200 != null) {
                return response.Code200;
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'ERP callout exception: ' + e.getMessage());
        }
        
        return new List<ExternalService.XaApiService_getItemInventoryByItemNumber_OUT_200>();
    }
    
    //4419
    public class InventoryLocationResult {
        @AuraEnabled public String locationDisplayName;
        @AuraEnabled public Decimal quantityAvailable;
        @AuraEnabled public String warehouseCode;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<InventoryLocationResult> getBulkInventoryStatus(Id productId) {      
        String productCode = [
            SELECT Id,
            ProductCode
            FROM Product2
            WHERE Id = :productId
            WITH SYSTEM_MODE
        ]?.ProductCode;
        
        List<ExternalService.XaApiService_getItemInventoryByItemNumber_OUT_200> erpData =
            fetchErpInventory(ProductCode);
        
        List<InventoryLocationResult> results = new List<InventoryLocationResult>();
        
        Set<String> erpWarehouseNames = new Set<String>();
        for (ExternalService.XaApiService_getItemInventoryByItemNumber_OUT_200 erpItem : erpData) {
            
            if (erpItem.warehouse != null && erpItem.warehouse.id != null) {
                erpWarehouseNames.add(erpItem.warehouse.id);
            }
        }
        Map<String,String> warehouseNameMap = InventoryLocationTransformer.getFriendlyLocationNamesBulk(erpWarehouseNames);
        
        List<InventoryLocationResult> warehouseList = new List<InventoryLocationResult>();
        
        for (ExternalService.XaApiService_getItemInventoryByItemNumber_OUT_200 erpItem : erpData) {
            
            Integer quantity = 0;

            if (erpItem.quantityAvailable != null) {
                quantity = Integer.valueOf(erpItem.quantityAvailable);
            } else if (erpItem.quantityAvailableToAssemble != null) {
                quantity = Integer.valueOf(erpItem.quantityAvailableToAssemble);
            }
            if (quantity > 0 && erpItem.warehouse != null) {
                InventoryLocationResult warehouse = new InventoryLocationResult();
                String erpWarehouseId = erpItem.warehouse.id;
                warehouse.warehouseCode = erpWarehouseId;
                warehouse.locationDisplayName =
                    warehouseNameMap.containsKey(erpWarehouseId)
                    ? warehouseNameMap.get(erpWarehouseId)
                    : erpItem.warehouse.name;
                
                warehouse.quantityAvailable = quantity;
                warehouseList.add(warehouse);
            }
        }
        return warehouseList;
    }
    
    @AuraEnabled(cacheable=true)
    public static String getProductCategoryName(Id recordId) {
        Product2 p = [
            SELECT  Category__c, Category__r.Name
            FROM Product2
            WHERE Id = :recordId
            LIMIT 1
        ];
        
        return p.Category__c != null ? p.Category__r.Name : null;
    }
    
}