/**
    * Copyright (c) 2022 ForeFront, Inc. All Rights Reserved.
    * Subject to ForeFront, Inc. licensing.
    *
    * @author Forefront
    * @version 1.0
    * @description
    *
    * PURPOSE
    * 
    *   Controller for SearchResultsControllerB2B
    * 
    * TEST CLASS 
    * 
    *   SearchResultsControllerB2B_TEST
    * 
    * CHANGE LOG 
    * 
    *    [Version; Date; Author; Description]
    *    v1.0; 4/18/22; Forefront; Initial Build
    * 
**/
public without sharing class SearchResultsControllerB2B {
    public static final String DEFAULT_PRODUCT_IMAGE_PLACEHOLDER = '/sfsites/c/file-asset-public/product_placeholder';

    public static final Integer MAX_PRODUCT_COUNT_PER_CONNECT_API_REQUEST = 20;

    /**
     * SOSL Special characters to escape per docs
     * https://developer.salesforce.com/docs/atlas.en-us.soql_sosl.meta/soql_sosl/sforce_api_calls_sosl_examples.htm
     */
    public static final Set<String> SOSL_SPECIAL_CHARS =
        new Set<String>('& | ! ( ) { } [ ] ^ " ~ * ? : \\ \' + -'.split(' '));
    // ===== NEW: add this block =====
    /**
     * Matches part numbers like PST-500X24 (also tolerates "PST-500 X 24").
     * These are tokenized as prefix / first number / second number instead of
     * letting the dimension regex collapse "500x24" into "50024".
     */
    @TestVisible
    private static final Pattern DASH_DIMENSION_PART_PATTERN =
        Pattern.compile('^([a-z]+)-(\\d+)\\s*x\\s*(\\d+)$');
    // ===== END NEW =====
    @TestVisible private static ConnectApi.SortRulesCollection mockSortRules;
    @TestVisible private static ConnectApi.ProductOverviewCollection mockProductOverviewCollection;
    @TestVisible private static ConnectApi.PricingResult mockPricingCollection;

    @AuraEnabled(Cacheable=true)
    public static List<SortRule> fetchSortRules() {
        ConnectApi.SortRulesCollection sortRulesCollection = Test.isRunningTest() ? mockSortRules : ConnectApi.CommerceSearch.getSortRules(BuyerService.currentWebStoreId);

        List<ConnectApi.SortRule> sortRules = sortRulesCollection.sortRules;

        List<SortRule> wrappers = new List<SortRule>();

        for (ConnectApi.SortRule sortRule : sortRules) {
            SortRule wrapper = new SortRule();
            wrapper.direction = ConnectApi.CommerceSearchSortRuleDirection.Ascending === sortRule.direction ? 'ASC' : 'DESC';
            wrapper.nameOrId = sortRule.nameOrId;
            wrapper.sortRuleId = sortRule.sortRuleId;
            wrapper.sortType = String.valueOf(sortRule.type);

            wrappers.add(wrapper);
        }

        return wrappers;
    }

    @AuraEnabled(Cacheable=false)
    public static SearchOutput catalogProductSearch(SearchInput input) {
        try {
            BuyerContext.overrideState(input.webstoreId, input.effectiveAccountId);

            Paginator paginator = new Paginator(input);
            CustomPaginator.PaginationResult paginationResult = paginator.run();

            SearchOutput output = new SearchOutput();
            output.pagination = paginationResult.settings;
            output.products = (List<ProductWrapper>) paginationResult.records;

            return output;
        }
        catch (Exception e) {
            System.debug(LoggingLevel.ERROR, e.getMessage());
            System.debug(LoggingLevel.ERROR, e.getStackTraceString());

            Logger.error('Failed to perform catalog product search', e);

            throw new AuraHandledException(
                AuraHandledExceptionBuilder.buildClientMessage(e)
            );
        }
        finally {
            Logger.saveLog();
        }
    }

    public class SearchOutput {
        @AuraEnabled public CustomPaginator.PaginationSettings pagination { get; set; }
        @AuraEnabled public List<ProductWrapper> products { get; set; }
    }

    public class SearchInput {
        @AuraEnabled public String effectiveAccountId { get; set; }
        @AuraEnabled public String webstoreId { get; set; }
        @AuraEnabled public CustomPaginator.PaginationSettings pagination { get; set; }
        @AuraEnabled public String searchQuery { get; set; }
        @AuraEnabled public String sortBy { get; set; }
        @AuraEnabled public String sortDirection { get; set; }
        @AuraEnabled public SortRule sortRule { get; set; }
        @AuraEnabled public List<SearchFacet> searchFacets { get; set; }
        @AuraEnabled public List<Id> categoryFilters { get; set; }

        public Boolean hasSearchQuery {
            get {
                return String.isNotBlank(searchQuery);
            }
        }

        public Boolean hasCategoryFilters {
            get {
                return categoryFilters != null && !categoryFilters.isEmpty();
            }
        }
    }

    private static List<String> soslTokenizeQuery(String searchQuery) {
        String normalizedQuery = searchQuery.trim().toLowerCase();

        // ===== NEW: special case for part numbers formatted like PST-500X24 =====
        Matcher partMatcher = DASH_DIMENSION_PART_PATTERN.matcher(normalizedQuery);
        if (partMatcher.matches()) {
            return new List<String>{
                partMatcher.group(1),  // pst
                partMatcher.group(2),  // 500
                partMatcher.group(3)   // 24
            };
        }
        // ===== END NEW =====
        
        Pattern decimalPattern = Pattern.compile('(\\d+\\.\\d+)|(\\d+\\sx\\s\\d+)|(\\d+x\\d+)');
        Matcher matcher = decimalPattern.matcher(normalizedQuery);

        Set<String> tokens = new Set<String>();

        while (matcher.find()) {
            tokens.add(matcher.group().replaceAll('[^0-9.]', ''));
        }

        String queryWithoutNumbers = matcher.replaceAll('');

        tokens.addAll(queryWithoutNumbers.splitByCharacterType());
        tokens.remove(null);

        Set<String> validTokens = new Set<String>();

        for (String token : tokens) {
            token = token.trim();

            if (SOSL_SPECIAL_CHARS.contains(token)) {
                token = '\\' + token;
            }

            validTokens.add(token);
        }

        // remove whitespace tokens
        validTokens.remove('');
        validTokens.remove(' ');
        validTokens.remove('\t');
        validTokens.remove('\r');
        validTokens.remove('\n');

        // even though '/' or '-' is not a sosl special char
        // queries containing it were not returning proper results
        validTokens.remove('/');
        validTokens.remove('-');

        return new List<String>(validTokens);
    }

    public without sharing class Paginator extends CustomPaginator {

        private SearchInput input;
        private final EntitledProductService.BuyerRecords buyerRecords;
        private Set<Id> soslFilteredProductIds;

        public Paginator(SearchInput input) {
            super(input.pagination);
            this.input = input;
            this.buyerRecords = EntitledProductService.getInstance()
                .fetchBuyerRecords(BuyerService.currentWebStoreId, BuyerService.effectiveAccountId);
        }

        public PaginationResult run() {
            List<CommerceEntitlementProduct> foundRecords = getQuery().toSObjectList();

            if (!input.hasSearchQuery) {
                return paginate(foundRecords);
            }
            
              if (foundRecords.size() > 1) {
    List<CommerceEntitlementProduct> promoted = new List<CommerceEntitlementProduct>();
    List<CommerceEntitlementProduct> remainder = new List<CommerceEntitlementProduct>();

    for (CommerceEntitlementProduct cep : foundRecords) {
      // Requires Product.Name and Product.XA_Product_Class__c selected in getQuery()
      SObject prod = cep.getSObject('Product');

      String partNumber = (prod == null) ? null : (String) prod.get('Name');
      String prodClass  = (prod == null) ? null : (String) prod.get('XA_Product_Class__c');

      Boolean isIdler = (prodClass != null && prodClass.equalsIgnoreCase('Idler'));
      Boolean endsWithSB = (partNumber != null && partNumber.trim().toUpperCase().endsWith('SB'));

      if (isIdler && endsWithSB) {
        promoted.add(cep);
      } else {
        remainder.add(cep);
      }
    }

    foundRecords.clear();
    foundRecords.addAll(promoted);
    foundRecords.addAll(remainder);
  }
  
            List<Product2> exactMatchProducts = [
                SELECT Id
                FROM Product2
                WHERE Name = :input.searchQuery
                WITH SYSTEM_MODE
                LIMIT 1
            ];

            if (exactMatchProducts.isEmpty()) {
                return paginate(foundRecords);
            }

            for (Integer i = 0; foundRecords.size() > 1 && i < foundRecords.size(); i++) {
                CommerceEntitlementProduct record = foundRecords[i];

                if(record.ProductId == exactMatchProducts[0].Id) {
                    CommerceEntitlementProduct match = foundRecords.remove(i);
                    foundRecords.add(0, match);
                    break;
                }
            }

            return paginate(foundRecords);
        }

        public override Query getQuery() {
            String sortField = String.valueOf(Product2.Name);

            if ('ProductBased'.equalsIgnoreCase(input.sortRule?.sortType)) {
                sortField = input.sortRule.nameOrId;
            }
            else if ('Relevancy'.equalsIgnoreCase(input.sortRule?.sortType)) {
                sortField = String.valueOf(Product2.Search_Boost_Level__c);
                input.sortRule.direction = 'DESC';
            }

            sortField = sortField.startsWith('Product.') ? sortField : 'Product.' + sortField;

            Query q = new Query(CommerceEntitlementProduct.SObjectType)
                .selectField(CommerceEntitlementProduct.ProductId)
                .selectField('Product.Name')
                .selectField('Product.XA_Product_Class__c')  // Needed to identify Idlers
                .orderBy(
                    sortField,
                    Optional.of(input.sortRule?.direction, 'ASC')
                );


            q.addConditionEq('Product.IsActive', true)
                .addConditionNotEq('Product.ProductClass', 'Variation')
                .addConditionIn('PolicyId', buyerRecords.policyIds)
                .addConditionEq('Policy.CanViewProduct', true)
                .addConditionEq('Policy.CanViewPrice', true)
                .addConditionEq('Policy.IsActive', true);

            if (input.hasSearchQuery) {

                if (this.soslFilteredProductIds == null) {
                    String soslFindTerm = '{' + String.join(soslTokenizeQuery(input.searchQuery), ' and ') + '}';

                    List<List<SObject>> soslResults = [
                        FIND :soslFindTerm
                        IN ALL FIELDS
                        RETURNING Commerce_Search_Index__c(Product__c ORDER BY Id LIMIT 2000) // without order clause it will return only 250 records
                    ];


                    this.soslFilteredProductIds = Stream.of(soslResults[0]).ids(Commerce_Search_Index__c.Product__c);
                }

                q.addConditionIn(CommerceEntitlementProduct.ProductId, this.soslFilteredProductIds);
            }

            if (input.hasCategoryFilters) {
                q.addConditionIn(CommerceEntitlementProduct.ProductId, new Query(ProductCategoryProduct.SObjectType)
                    .selectField('ProductId')
                    .addCondition(Query.doOr(new List<Query.Condition>{
                        Query.conditionIn('ProductCategoryId', input.categoryFilters),
                        Query.conditionIn('ProductCategory.ParentCategoryId', input.categoryFilters),
                        Query.conditionIn('ProductCategory.ParentCategory.ParentCategoryId', input.categoryFilters),
                        Query.conditionIn('ProductCategory.ParentCategory.ParentCategory.ParentCategoryId', input.categoryFilters),
                        Query.conditionIn('ProductCategory.ParentCategory.ParentCategory.ParentCategory.ParentCategoryId', input.categoryFilters)
                    }))
                );
            }

            if (!input.searchFacets.isEmpty()) {
                for (SearchFacet facet : input.searchFacets) {
                    if ('Custom'.equalsIgnoreCase(facet.attributeType)) {
                        for (String value : facet.values) {
                            q.addConditionEq('Product.' + facet.nameOrId, value);
                        }
                    }
                }
            }

            return q;
        }

        protected override Object processBeforeReturn(List<SObject> records) {
            List<Id> productIds = new List<Id>();

            for (CommerceEntitlementProduct record : (List<CommerceEntitlementProduct>) records) {
                if(productIds.contains(record.ProductId)) {
                    continue;
                }
                productIds.add(record.ProductId);
            }

            if (productIds.isEmpty()) {
                return new List<ProductWrapper>();
            }

            return createProductWrappers(productIds);
        }
    }

    @TestVisible
    private static Object createProductWrappers(List<Id> productIds) {

        Integer loopsCount = Math.ceil(productIds.size() / Decimal.valueOf(MAX_PRODUCT_COUNT_PER_CONNECT_API_REQUEST)).intValue();

        Map<Id, ProductWrapper> productWrappers = new Map<Id, ProductWrapper>();

        for (Integer i = 0; i < loopsCount; i++) {
            List<Id> productIdsCurrentChunk = CollectionUtils.splice(
                MAX_PRODUCT_COUNT_PER_CONNECT_API_REQUEST * i,
                MAX_PRODUCT_COUNT_PER_CONNECT_API_REQUEST,
                productIds
            );

            ConnectApi.ProductOverviewCollection productOverviewCollection = Test.isRunningTest()
                ? mockProductOverviewCollection
                : ConnectApi.CommerceCatalog.getProducts(
                    BuyerService.currentWebStoreId,
                    BuyerService.effectiveAccountId,
                    productIdsCurrentChunk,
                    null,
                    null,
                    false,
                    false
                );

            ConnectApi.PricingInput pricingInput = new ConnectApi.PricingInput();
            pricingInput.pricingLineItems = new List<ConnectApi.PricingLineItemInput>();

            for (Id productId : productIdsCurrentChunk) {
                ConnectApi.PricingLineItemInput item = new ConnectApi.PricingLineItemInput();
                item.productId = productId;

                pricingInput.pricingLineItems.add(item);
            }

            ConnectApi.PricingResult pricingResult = Test.isRunningTest()
                ? mockPricingCollection
                : ConnectApi.CommerceStorePricing.getProductPrices(
                    BuyerService.currentWebStoreId,
                    BuyerService.effectiveAccountId,
                    pricingInput
                );


            for (ConnectApi.ProductOverview productOverview : productOverviewCollection.getProducts()) {
                ProductWrapper productWrapper = new ProductWrapper();
                productWrapper.sfid = productOverview.id;
                productWrapper.imageUrl = productOverview?.defaultImage?.url;

                if (String.isBlank(productWrapper.imageUrl) || productWrapper.imageUrl.contains('default-product-image')) {
                    productWrapper.imageUrl = DEFAULT_PRODUCT_IMAGE_PLACEHOLDER;
                }

                productWrapper.fields = productOverview.fields;
                productWrappers.put(productWrapper.sfid, productWrapper);
            }

            for (ConnectApi.PricingResultLineItem item : pricingResult.pricingLineItemResults) {
                ProductWrapper productWrapper = productWrappers.get(item.productId);
                productWrapper.unitPrice = Decimal.valueOf(item.unitPrice);
                productWrapper.currencyIsoCode = pricingResult.currencyIsoCode;
                productWrapper.prices = item;
            }
        }

        List<ProductWrapper> wrappers = productWrappers.values();

        return wrappers;
    }
    
    /**
    * @description Exposes PLP inventory availability calculation to presentation layer.
    * @param productCodes List of visible product SKUs on the current page.
    * @param categoryId Active category context from PLP navigation.
    * @param webStoreId Context webstore identifier.
    * @return Product SKU indexed inventory availability details.
    */
    @AuraEnabled
    public static Map<String, InventoryServiceB2B.AvailabilityWrapper> getPLPAvailability(List<String> productCodes, Id categoryId, Id webStoreId) {
        try {
            return InventoryServiceB2B.calculateAvailability(productCodes, categoryId, webStoreId);
        } catch (Exception e) {
            Logger.error('Failed to resolve PLP inventory availability status', e);
            throw new AuraHandledException(e.getMessage());
        } finally {
            Logger.saveLog();
        }
    }

    public class ProductWrapper {
        @AuraEnabled public Id sfid { get; set; }
        @AuraEnabled public Decimal unitPrice { get; set; }
        @AuraEnabled public String currencyIsoCode { get; set; }
        @AuraEnabled public String imageUrl { get; set; }
        @AuraEnabled public Map<String, Object> fields { get; set; }
        @AuraEnabled public ConnectApi.PricingResultLineItem prices { get; set; }
    }

    public class SortRule {
        @AuraEnabled public String direction { get; set; }
        @AuraEnabled public String nameOrId { get; set; }
        @AuraEnabled public String sortRuleId { get; set; }
        @AuraEnabled public String sortType { get; set; }
    }

    public class SearchFacet {
        @AuraEnabled public String attributeType { get; set; }
        @AuraEnabled public String facetType { get; set; }
        @AuraEnabled public String nameOrId { get; set; }
        @AuraEnabled public List<String> values { get; set; }
    }
}