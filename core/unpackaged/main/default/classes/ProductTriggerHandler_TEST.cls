/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/forefront
 * @date 29.07.2024
 * @test ProductTriggerHandler_TEST_TEST
 * 
 **/

@IsTest
private class ProductTriggerHandler_TEST {
	@IsTest
	static void testBehavior() {
		// given
		Product2 product = new Product2(
			Name = 'test'
		);

		// when
		insert product;

		// then
		List<Commerce_Search_Index__c> indices = [
			SELECT Id, Unique_Product_Id__c, Search_Phrases__c FROM Commerce_Search_Index__c
		];

		Assert.areEqual(1, indices.size());
		Assert.areEqual(product.Id, indices[0].Unique_Product_Id__c);
		Assert.areEqual(product.Name, indices[0].Search_Phrases__c);


		// when
		product.Name = 'Changed Name';
		update product;

		Id oldIndexId = indices[0].Id;

		indices = [
			SELECT Id, Unique_Product_Id__c, Search_Phrases__c FROM Commerce_Search_Index__c
		];

		Assert.areEqual(1, indices.size(), 'should not create new index record');
		Assert.areEqual(oldIndexId, indices[0].Id, 'existing index should be updated');
		Assert.areEqual(product.Id, indices[0].Unique_Product_Id__c, 'product it should remain the same');
		Assert.areEqual(product.Name, indices[0].Search_Phrases__c, 'search phrase should be updated');
	}
}