/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/forefront
 * @date 29.07.2024
 * @test CommerceSearchIndexBatch_TEST_TEST
 * 
 **/

@IsTest
private class CommerceSearchIndexBatch_TEST {
	@TestSetup
	static void setup() {
		TriggerHandler.bypass('ProductTriggerHandler');

		List<Product2> products = new List<Product2>();
		for (Integer i = 0; i < 5; i++) {
			products.add(new Product2(
				Name = 'Test Product ' + i
			));
		}
		insert products;
	}

	@IsTest
	static void testBehavior() {
		// given
		Assert.areEqual(0, [SELECT COUNT() FROM Commerce_Search_Index__c]);

		// when
		Test.startTest();
		CommerceSearchIndexBatch.reindex();
		Test.stopTest();

		// then
		Assert.areEqual(5, [SELECT COUNT() FROM Commerce_Search_Index__c], 'should create 5 search indices one for each product');
	}
}