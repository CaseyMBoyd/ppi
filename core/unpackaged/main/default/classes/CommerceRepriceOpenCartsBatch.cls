/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @description
 * @date 23/12/2024
 * @test CommerceRepriceOpenCartsBatch_TEST
 *
 */

public with sharing class CommerceRepriceOpenCartsBatch implements Database.Batchable<SObject>, Database.Stateful {

	private static final String LOGGER_TAG = 'Cart Reprice';

	private final Set<String> cartStatuses;
	private final String transactionId = Logger.getTransactionId();

	public CommerceRepriceOpenCartsBatch() {
		this(new Set<String>{
			'Active',
			'Checkout'
		});
	}

	public CommerceRepriceOpenCartsBatch(Set<String> cartStatuses) {
		this.cartStatuses = cartStatuses;
	}

	public Database.QueryLocator start(Database.BatchableContext context) {
		Query q = new Query(WebCart.SObjectType)
			.selectFields(
				new List<SObjectField>{
					WebCart.Id,
					WebCart.Name,
					WebCart.Status,
					WebCart.AccountId,
					WebCart.WebStoreId
				}
			)
			.addConditionIn(WebCart.Status, this.cartStatuses)
			.orderBy('CreatedDate', 'DESC');

		Logger.info('Starting cart reprice with query: ' + q.toQueryString())
			.addTag(LOGGER_TAG);

		return q.getQueryLocator();
	}

	public void execute(Database.BatchableContext context, List<WebCart> scope) {
		Logger.setParentLogTransactionId(this.transactionId);

		for (WebCart cart : scope) {
			try {
				ConnectApi.CommerceCart.calculateCart(
					cart.WebStoreId,
					cart.Id,
					cart.AccountId
				);
				Logger.info('Cart repriced successfully')
					.addTag(LOGGER_TAG)
					.setRecord(cart.Id);
			}
			catch (Exception ex) {
				Logger.error('Error during reprice', ex)
					.addTag(LOGGER_TAG)
					.setRecord(cart.Id);
			}
		}

		Logger.saveLog();
	}

	public void finish(Database.BatchableContext context) {
		Logger.info('Batch process completed')
			.addTag(LOGGER_TAG);
		Logger.saveLog();
	}
}