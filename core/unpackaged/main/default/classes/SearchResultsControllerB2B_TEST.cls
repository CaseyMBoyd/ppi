/**
 * Copyright (c) 2023 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @date 17.01.2023
 * @description Test suite
 *
 */

@IsTest
private class SearchResultsControllerB2B_TEST {
	private final static String PRODUCT_CODE = '00001';

	@TestSetup
	static void makeData() {
		b2btd.xWebstore store = new b2btd.xWebstore();
		store.persist();

		b2btd.xAccount account = new b2btd.xAccount()
			.ofType('Test')
			.makeBuyerAccount();
		account.persist();

		b2btd.xProductCatalog catalog = new b2btd.xProductCatalog();
		catalog.persist();

		b2btd.xProductCategory category = new b2btd.xProductCategory(catalog.id)
			.name('Test Products');
		category.persist();

		b2btd.xProductCategory childCategory = new b2btd.xProductCategory(catalog.id)
			.name('Test Products Child')
			.withParent(category.id);

		childCategory.persist();
		b2btd.xProduct product = new b2btd.xProduct()
			.productCode(PRODUCT_CODE);
		product.persist();
		new b2btd.xProductCategoryProduct(product.id, childCategory.id).persist();

		b2btd.xBuyerGroup buyerGroup = new b2btd.xBuyerGroup();

		b2btd.xBuyerGroupMember buyerGroupMember = new b2btd.xBuyerGroupMember(account, buyerGroup);
		buyerGroupMember.persist();

		b2btd.xPricebook pricebook = new b2btd.xPricebook()
			.active(true)
			.validFrom(System.today().addMonths(-1))
			.validTo(System.today().addMonths(1));

		pricebook.persist();
		new b2btd.xBuyerGroupPricebook(buyerGroup, pricebook).persist();

		new b2btd.xStandardPricebookEntry(product).price(300).persist();
		b2btd.xPricebookEntry entryPriority1 = new b2btd.xPricebookEntry(product, pricebook)
			.price(250)
			.active();
		entryPriority1.persist();
		CommerceEntitlementPolicy policy = new CommerceEntitlementPolicy(
			Name = 'Test policy',
			IsActive = true,
			CanViewProduct = true,
			CanViewPrice = true
		);
		insert policy;
		CommerceEntitlementProduct commerceEntitlementProduct = new CommerceEntitlementProduct(
			ProductId = product.id,
			PolicyId = policy.Id
		);
		insert commerceEntitlementProduct;

		CommerceEntitlementBuyerGroup commerceEntitlementBuyerGroup = new CommerceEntitlementBuyerGroup(
			PolicyId = policy.Id,
			BuyerGroupId = buyerGroup.id
		);
		insert commerceEntitlementBuyerGroup;
		b2btd.xWebstoreBuyerGroup webstoreBuyerGroup = new b2btd.xWebstoreBuyerGroup(store, buyerGroup);
		webstoreBuyerGroup.persist();
	}

	@IsTest
	static void whenGivenSearchInput_shouldReturnSearchOutput() {
		// given
		WebStore store = [SELECT Id FROM WebStore];
		Account account = [SELECT Id FROM Account];
		ProductCategory childCategory = [SELECT Id FROM ProductCategory WHERE ParentCategoryId != NULL];
		Product2 product = [SELECT Name FROM Product2 WHERE ProductCode = :PRODUCT_CODE LIMIT 1];

		DI.Mock mock = DI.mock(BuyerContext.class);
		mock.startStubbing();
		mock.when(BuyerContext.getInstance().getWebstore()).thenReturn(store);
		mock.when(BuyerContext.getInstance().getNetwork()).thenReturn(new Schema.Network(Id = b2btd.generateFakeId(Network.SObjectType)));
		mock.when(BuyerContext.getInstance().getEffectiveAccount()).thenReturn(account);
		mock.when(BuyerContext.getInstance().getEffectiveAccountId()).thenReturn(account.Id);
		mock.stopStubbing();

		CustomPaginator.PaginationSettings pagination = new CustomPaginator.PaginationSettings();
		pagination.firstPage = 1;
		pagination.pageSize = 20;
		pagination.currentPage = 1;
		pagination.totalPages = 1;
		pagination.totalRecords = 0;

		SearchResultsControllerB2B.SearchInput searchInput = new SearchResultsControllerB2B.SearchInput();
		searchInput.searchQuery = PRODUCT_CODE;
		searchInput.pagination = pagination;
		searchInput.categoryFilters = new List<Id>{
			childCategory.Id
		};

		SearchResultsControllerB2B.SortRule sortRule = new SearchResultsControllerB2B.SortRule();
		sortRule.direction = 'DESC';
		sortRule.sortType = 'Relevancy';
		sortRule.nameOrId = 'Best Match';

		searchInput.sortRule = sortRule;

		SearchResultsControllerB2B.SearchFacet searchFacet = new SearchResultsControllerB2B.SearchFacet();
		searchFacet.attributeType = 'Custom';
		searchFacet.nameOrId = 'Name';
		searchFacet.values = new List<String>{
			product.Name
		};

		searchInput.searchFacets = new List<SearchResultsControllerB2B.SearchFacet>{
			searchFacet
		};


		// when
		SearchResultsControllerB2B.SearchOutput searchOutput = SearchResultsControllerB2B.catalogProductSearch(searchInput);

		// then
		Assert.areEqual(0, searchOutput.products.size());
		Assert.areEqual(0, searchOutput.pagination.totalRecords);
		Assert.areEqual(0, searchOutput.pagination.totalPages);
		Assert.areEqual(1, searchOutput.pagination.currentPage);
	}

	@IsTest
	static void testCatalogSearch_failure() {
		// given
		SearchResultsControllerB2B.SearchInput input = null;
		Boolean exThrown = false;

		// when
		try {
			SearchResultsControllerB2B.catalogProductSearch(input);
			Assert.fail();
		}
		catch (Exception ex) {
			exThrown = true;
		}

		// then
		Assert.isTrue(exThrown, 'Expected exception to be thrown');
	}

	@IsTest
	static void testFetchSortRules() {
		// given
		ConnectApi.SortRule sortRule = new ConnectApi.SortRule();
		sortRule.nameOrId = 'Best Match';
		sortRule.direction = ConnectApi.CommerceSearchSortRuleDirection.Ascending;
		sortRule.sortRuleId = 'sort_rule_id';
		sortRule.type = ConnectApi.CommerceSearchSortRuleType.Relevancy;

		SearchResultsControllerB2B.mockSortRules = new ConnectApi.SortRulesCollection();
		SearchResultsControllerB2B.mockSortRules.sortRules = new List<ConnectApi.SortRule>{
			sortRule
		};

		// when
		List<SearchResultsControllerB2B.SortRule> actual = SearchResultsControllerB2B.fetchSortRules();

		// then
		Assert.areEqual(1, actual.size());

		Assert.areEqual(sortRule.nameOrId, actual[0].nameOrId);
		Assert.areEqual(sortRule.nameOrId, actual[0].nameOrId);

		Assert.areEqual('Relevancy', actual[0].sortType);
		Assert.areEqual('ASC', actual[0].direction);
	}

	@IsTest
	static void testCreateProductWrappers() {
		// given
		Product2 product = [SELECT Id FROM Product2 WHERE ProductCode = :PRODUCT_CODE LIMIT 1];

		ConnectApi.ProductOverviewCollection productOverviewCollection = new ConnectApi.ProductOverviewCollection();
		ConnectApi.ProductOverview productOverview = new ConnectApi.ProductOverview();
		productOverview.defaultImage = new ConnectApi.ProductMedia();
		productOverview.defaultImage.url = 'default-product-image';
		productOverview.id = product.Id;

		productOverviewCollection.products = new List<ConnectApi.ProductOverview>{
			productOverview
		};

		SearchResultsControllerB2B.mockProductOverviewCollection = productOverviewCollection;

		ConnectApi.PricingResult pricingResult = new ConnectApi.PricingResult();
		pricingResult.currencyIsoCode = 'USD';
		ConnectApi.PricingResultLineItem pricingLineItem = new ConnectApi.PricingResultLineItem();

		pricingLineItem.productId = product.Id;
		pricingLineItem.unitPrice = '100';

		pricingResult.pricingLineItemResults = new List<ConnectApi.PricingResultLineItem>{
			pricingLineItem
		};

		SearchResultsControllerB2B.mockPricingCollection = pricingResult;

		// when
		List<SearchResultsControllerB2B.ProductWrapper> wrappers = (List<SearchResultsControllerB2B.ProductWrapper>)
			SearchResultsControllerB2B.createProductWrappers(new List<Id>{
				product.Id
			});

		// then
		Assert.areEqual(1, wrappers.size());
		Assert.areEqual(product.Id, wrappers[0].sfid);
		Assert.areEqual(SearchResultsControllerB2B.DEFAULT_PRODUCT_IMAGE_PLACEHOLDER, wrappers[0].imageUrl);
		Assert.areEqual(100, wrappers[0].unitPrice);
		Assert.areEqual('USD', wrappers[0].currencyIsoCode);
	}
     private class InventoryMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setStatusCode(200);
            response.setBody('[{"sku":"TEST-SKU","quantity":20,"warehouseCode":"SC01"}]');
            return response;
        }
    }

    @IsTest
    static void testGetPLPAvailability() {
        ProductCatalog catalogRecord = new ProductCatalog(Name = 'Test Catalog');
        insert catalogRecord;

        ProductCategory categoryRecord = new ProductCategory(Name = 'Test Category', CatalogId = catalogRecord.Id, Low_Stock_Threshold__c = 10);
        insert categoryRecord;

        Product2 productRecord = new Product2(Name = 'Test Product', ProductCode = 'TEST-SKU', IsActive = true);
        insert productRecord;

        insert new ProductCategoryProduct(ProductId = productRecord.Id, ProductCategoryId = categoryRecord.Id);

        Test.setMock(HttpCalloutMock.class, new InventoryMock());

        Test.startTest();

        Map<String, InventoryServiceB2B.AvailabilityWrapper> result = SearchResultsControllerB2B.getPLPAvailability(
            new List<String>{'TEST-SKU'},
            categoryRecord.Id,
            '0ZE000000000001'
        );

        Test.stopTest();
    }
}