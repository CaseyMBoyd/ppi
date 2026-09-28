/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/forefront
 * @date 29.07.2024
 * @test CommerceSearchIndexBatch_TEST
 * 
 **/

public without sharing class CommerceSearchIndexBatch implements Database.Batchable<SObject>, Database.Stateful {
	private final static Set<SObjectField> FIELDS_TO_TOKENIZE = new Set<SObjectField>{
		Product2.StockKeepingUnit,
		Product2.ProductCode
	};

	public static Id reindex() {
		return Database.executeBatch(new CommerceSearchIndexBatch(), 200);
	}

	private Set<String> searchableFields;

	public Database.QueryLocator start(Database.BatchableContext context) {
		this.searchableFields = getSearchableFields();

		return Database.getQueryLocator(
			String.format('SELECT {0} FROM Product2', new List<String>{
				String.join(this.searchableFields, ',')
			})
		);
	}


	public void execute(Database.BatchableContext context, List<Product2> products) {

		try {
			List<Database.UpsertResult> upsertResults = createProductIndices(products, this.searchableFields);
			Logger.logDatabaseErrors(LoggingLevel.ERROR, 'Failed to upsert Commerce Search Index', upsertResults);
		}
		catch (Exception ex) {
			Logger.error('Error creating Product Search Indices', ex);
		}
		finally {
			Logger.saveLog();
		}
	}

	public static List<Database.UpsertResult> createProductIndices(List<Product2> products, Set<String> searchableFields) {
		List<Commerce_Search_Index__c> indicesToUpsert = new List<Commerce_Search_Index__c>();

		for (Product2 product : products) {

			List<String> values = new List<String>();

			for (String searchableField : searchableFields) {
				Map<String, Object> populatedFields = mapToLowercase(product.getPopulatedFieldsAsMap());

				String value = String.valueOf(populatedFields.get(searchableField) ?? '');

				values.add(value);

				if(shouldTokenize(searchableField)) {
					values.add(String.join(value.splitByCharacterType(), ' '));
				}
			}

			indicesToUpsert.add(
				new Commerce_Search_Index__c(
					Product__c = product.Id,
					Unique_Product_Id__c = product.Id,
					Search_Phrases__c = String.join(values, ' ')
				)
			);
		}

		List<Database.UpsertResult> upsertResults = Database.upsert(
			indicesToUpsert,
			Commerce_Search_Index__c.Unique_Product_Id__c,
			false,
			AccessLevel.SYSTEM_MODE
		);
		return upsertResults;
	}

	private static Boolean shouldTokenize(String fieldToTest) {
		for(SObjectField field : FIELDS_TO_TOKENIZE) {
			if(String.valueOf(field).equalsIgnoreCase(fieldToTest)) {
				return true;
			}
		}

		return false;
	}

	public void finish(Database.BatchableContext context) {
	}

	public static Set<String> getSearchableFields() {
		List<String> configuredFields = Test.isRunningTest()
			?  new List<String>{'Name'}
			: (Commerce_Setting__mdt.getInstance('PPI_Commerce')?.Product_Searchable_Fields__c ?? '').split('\n');

		Set<String> existingFields = Product2.getSObjectType().getDescribe().fields.getMap().keySet();
		Set<String> searchableFields = new Set<String>();

		for (String configuredField : configuredFields) {
			String sanitizedField = (configuredField ?? '').trim().toLowerCase();

			if (existingFields.contains(sanitizedField)) {
				searchableFields.add(sanitizedField);
			}
		}

		return searchableFields;
	}

	private static Map<String, Object> mapToLowercase(Map<String, Object> objectMap) {
		Map<String, Object> lowercased = new Map<String, Object>();

		for (String key : objectMap.keySet()) {
			lowercased.put(key.toLowerCase(), objectMap.get(key));
		}

		return lowercased;
	}

}