/**
	* Copyright (c) 2021 ForeFront, Inc. All Rights Reserved.
	* Subject to ForeFront, Inc. licensing.
	*
	* @author Forefront
	* @version 1.0
	* @description
	*
	* CHANGE LOG
	*
	*    [Version; Date; Author; Description]
	*    v1.0; 10/13/2021; Forefront; Initial Build
	*
**/

@IsTest
private class EntitledProductService_TEST {


	@IsTest
	static void fetchBuyerRecordsTest(){
		// given
		setUpData();
		WebStore store = [SELECT Id FROM WebStore LIMIT 1];
		Account account = [SELECT Id FROM Account LIMIT 1];

		// when
		EntitledProductService.BuyerRecords expected = EntitledProductService.getInstance().fetchBuyerRecords(store.Id, account.Id);

		// then
		Assert.areEqual(store.Id, expected.webStore.Id);
		Assert.isFalse(expected.policyIds.isEmpty());
		Assert.isFalse(expected.pricebookIds.isEmpty());
		Assert.isFalse(expected.members.isEmpty());
	}


	private static void setUpData(){
		String validSku = 'valid-sku';
		b2btd.xWebstore store = new b2btd.xWebstore();
		b2btd.xAccount account = new b2btd.xAccount().makeBuyerAccount();
		b2btd.xProduct product = new b2btd.xProduct().sku(validSku);
		product.persist();

		ProductCatalog catalog = new ProductCatalog(
			Name = 'main_catalog'
		);
		insert catalog;

		ProductCategory mainCategory = new ProductCategory(
			Name = 'Main_category',
			CatalogId = catalog.Id
		);
		insert mainCategory;

		ProductCategoryProduct productCategory = new ProductCategoryProduct(
			ProductId = product.id,
			ProductCategoryId = mainCategory.Id
		);
		insert productCategory;

		b2btd.xBuyerGroup buyerGroup = new b2btd.xBuyerGroup();

		b2btd.xBuyerGroupMember buyerGroupMember = new b2btd.xBuyerGroupMember(account, buyerGroup);
		buyerGroupMember.persist();

		b2btd.xPricebook pricebook = new b2btd.xPricebook()
			.active(true)
			.validFrom(Date.today().addDays(-1))
			.validTo(Date.today().addYears(10));

		pricebook.persist();

		new b2btd.xStandardPricebookEntry(product).price(300).persist();
		b2btd.xPricebookEntry entryPriority1 = new b2btd.xPricebookEntry(product, pricebook).price(250).active();
		entryPriority1.persist();


		CommerceEntitlementPolicy policy = new CommerceEntitlementPolicy(
			Name = 'Test policy',
			IsActive = true,
			CanViewPrice = true,
			CanViewProduct = true
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

		BuyerGroupPricebook buyerGroupPricebook = new BuyerGroupPricebook(
			BuyerGroupId = buyerGroup.id,
			Pricebook2Id = pricebook.id,
			IsActive = true
		);
		insert buyerGroupPricebook;

		b2btd.xWebstoreBuyerGroup webstoreBuyerGroup = new b2btd.xWebstoreBuyerGroup(store, buyerGroup);
		webstoreBuyerGroup.persist();


		DI.Mock mock = DI.mock(BuyerContext.class);
		mock.startStubbing();
		mock.when(BuyerContext.getInstance().getWebstore()).thenReturn(store.getRecord());
		mock.when(BuyerContext.getInstance().getEffectiveAccount()).thenReturn(new Account(Id = account.id));
		mock.when(BuyerContext.getInstance().getEffectiveAccountId()).thenReturn(account.id);
		mock.stopStubbing();
	}
}