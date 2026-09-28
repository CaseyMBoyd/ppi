/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author jakub_cichacki/Forefront
 * @date 27.06.2024
 * @test ProductController_TEST
 **/
public without sharing class ProductController {

    public static final String BUSHINGS_CATEGORY_NAME = 'Bushings';
    public static final Commerce_Setting__mdt COMMERCE_SETTING = Commerce_Setting__mdt.getInstance('PPI_Commerce');
    public static final String STEEL_MATERIAL = 'Steel';
    public static final String STEEL_304_MATERIAL = '304 Stainless Steel';
    public static final String STEEL_316_MATERIAL = '316 Stainless Steel';
    public static final List<String> bushingRelatedCategories = new List<String>{
            'Drum Pulleys',
            'Herringbone Wing',
            'Wing Pulleys'
    };

    public static final List<String> steelOptions = new List<String>{STEEL_MATERIAL, STEEL_304_MATERIAL, STEEL_316_MATERIAL};

    @AuraEnabled(Cacheable=true)
    public static List<PicklistWrapper> getBushingsForProduct(Id productId) {
        List<PicklistWrapper> results = new List<PicklistWrapper>();

        EntitledProductService.BuyerRecords buyerRecords = EntitledProductService.getInstance()
                .fetchBuyerRecords(BuyerService.currentWebStoreId, BuyerService.effectiveAccountId);

        Product2 product = (Product2) new Query(Product2.SObjectType)
                .selectFields('ProductCode, Default_Bushing_Bore__c, Hub_Series__c')
                .addSubquery(
                        Query.subquery('ProductCategoryProducts')
                                .selectFields('ProductCategory.Name')
                                .selectFields('ProductCategory.ParentCategory.Name')
                )
                .byId(productId)
                .fetch();

        Boolean canShowBushing = false;

        for(ProductCategoryProduct productCategoryProduct : product.ProductCategoryProducts) {
            if(bushingRelatedCategories.contains(productCategoryProduct.ProductCategory.Name)
                    || bushingRelatedCategories.contains(productCategoryProduct.ProductCategory.ParentCategory.Name)) {
                canShowBushing = true;
            }
        }

        if(canShowBushing) {
            List<ProductCategoryProduct> productCategoryProducts = (List<ProductCategoryProduct>) new Query(ProductCategoryProduct.SObjectType)
                    .selectFields('Product.Name, Product.Material__c, Product.Bore__c')
                    .addConditionEq('ProductCategory.Name', BUSHINGS_CATEGORY_NAME)
                    .addConditionEq('Product.IsActive', true)
                    .addConditionNull('Product.Keyway_Type__c')
                    .addConditionEq('Product.Hub_Series__c', product.Hub_Series__c)
                    .addConditionNotNull('Product.Hub_Series__c')
                    .addConditionIn('ProductId', new Query(CommerceEntitlementProduct.SObjectType).selectField('ProductId')
                            .addConditionIn('PolicyId', Stream.of(buyerRecords.policies).toSetOfIds(CommerceEntitlementBuyerGroup.PolicyId))
                    )
                    .orderBy('Product.Material__c, Product.Bore__c')
                    .run();

            Id defaultProductCategoryProduct = getDefaultProductCategoryProductId(productCategoryProducts, product);

            for (ProductCategoryProduct productCategoryProduct : productCategoryProducts) {
                results.add(new PicklistWrapper(
                        productCategoryProduct.Product.Bore__c,
                        productCategoryProduct.Product.Material__c,
                        productCategoryProduct.ProductId,
                        defaultProductCategoryProduct != null ? productCategoryProduct.Id == defaultProductCategoryProduct : false
                ));
            }

            results.sort();
        }

        return results;
    }

    private static Id getDefaultProductCategoryProductId(List<ProductCategoryProduct> productCategoryProducts, Product2 product) {
        List<String> materials = COMMERCE_SETTING.List_Of_Default_Materials_For_Bushings__c.split(';');
        Map<String, List<ProductCategoryProduct>> defaultsToVerifyByMaterial = new Map<String, List<ProductCategoryProduct>>{
                'default' => new List<ProductCategoryProduct>()
        };
        for (String material : materials) {
            defaultsToVerifyByMaterial.put(material, new List<ProductCategoryProduct>());
        }

        for (ProductCategoryProduct productCategoryProduct : productCategoryProducts) {
            if (productCategoryProduct.Product.Bore__c != null && product.Default_Bushing_Bore__c != null &&
                    productCategoryProduct.Product.Bore__c == Decimal.valueOf(product.Default_Bushing_Bore__c)) {
                if(defaultsToVerifyByMaterial.containsKey(productCategoryProduct.Product.Material__c)) {
                    defaultsToVerifyByMaterial.get(productCategoryProduct.Product.Material__c).add(productCategoryProduct);
                } else {
                    defaultsToVerifyByMaterial.get('default').add(productCategoryProduct);
                }
            }
        }

        for (List<ProductCategoryProduct> categoryProducts : defaultsToVerifyByMaterial.values()) {
            if (categoryProducts.size() == 1) {
                return categoryProducts[0].Id;
            }
        }

        return null;
    }

    public class PicklistWrapper implements Comparable {
        @AuraEnabled
        public Decimal bore { get; set; }
        @AuraEnabled
        public String material { get; set; }
        @AuraEnabled
        public String value { get; set; }
        @AuraEnabled
        public Boolean isDefault { get; set; }

        public PicklistWrapper currentPicklistWrapper;

        public PicklistWrapper(Decimal bore, String material, String value, Boolean isDefault) {
            this.bore = bore;
            this.material = material;
            this.value = value;
            this.isDefault = isDefault;
            currentPicklistWrapper = this;
        }

        public Integer compareTo(Object toBeCompared) {

            PicklistWrapper nextPicklistWrapper = (PicklistWrapper) toBeCompared;

            if (currentPicklistWrapper.material == nextPicklistWrapper.material) {
                return (Integer) (currentPicklistWrapper.bore - nextPicklistWrapper.bore);
            } else {
                if(steelOptions.contains(currentPicklistWrapper.material) && steelOptions.contains(nextPicklistWrapper.material)) {
                    return steelOptions.indexOf(currentPicklistWrapper.material) - steelOptions.indexOf(nextPicklistWrapper.material);
                } else if(steelOptions.contains(currentPicklistWrapper.material)) {
                    return -1;
                } else if(steelOptions.contains(nextPicklistWrapper.material)) {
                    return 1;
                } else {
                    return currentPicklistWrapper.material.compareTo(nextPicklistWrapper.material);
                }
            }
        }
    }

}