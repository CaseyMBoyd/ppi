/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/forefront
 * @date 29.07.2024
 * @test ProductTriggerHandler_TEST
 * 
 **/

public inherited sharing class ProductTriggerHandler extends TriggerHandler {

	protected override void afterInsert() {
		createCommerceSearchIndices(Trigger.new);
	}

	protected override void afterUpdate() {
		createCommerceSearchIndices(Trigger.new);
	}

	private void createCommerceSearchIndices(List<Product2> products) {
		try {
			List<Database.UpsertResult> upsertResults =
				CommerceSearchIndexBatch.createProductIndices(products, CommerceSearchIndexBatch.getSearchableFields());

			Logger.logDatabaseErrors(LoggingLevel.ERROR, 'Failed to upsert Commerce Search Index', upsertResults);
		}
		catch (Exception ex) {
			Logger.error('Error creating Product Search Indices', ex);
		}
		finally {
			Logger.saveLog();
		}
	}
}