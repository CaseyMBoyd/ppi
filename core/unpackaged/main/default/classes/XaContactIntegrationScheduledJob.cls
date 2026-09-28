/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @description
 * @date 15.03.2024 <p/>
 * @test XaContactIntegrationScheduledJob_TEST
 *
 */

public with sharing class XaContactIntegrationScheduledJob implements
		Database.Batchable<SObject>,
		Database.Stateful,
		Database.AllowsCallouts,
		Schedulable
{

	private final static String CRON_HOURLY_INTERVAL = '0 0 * * * ?';
	private final static Integer MAX_BATCH_SIZE = 1;

	private final String transactionID = Logger.getTransactionId();

	public static Id scheduleToRunHourly() {
		final String jobName = Test.isRunningTest()
			? 'TestXaContactIntegrationJob'
			: 'XaContactIntegrationJob';

		return System.schedule(jobName, CRON_HOURLY_INTERVAL, new XaContactIntegrationScheduledJob());
	}

	@TestVisible
	private XaContactIntegrationScheduledJob() {}

	public Database.QueryLocator start(Database.BatchableContext context) {
		return Database.getQueryLocator([
			SELECT Id,
				Name,
				Email,
				Account.companyNumber__c,
				Account.externalId__c,
				Account.Parent.externalId__c
			FROM Contact
			WHERE XA_Integrated__c = FALSE
			AND CreatedDate >=: Datetime.now().addHours(-1).addMinutes(-10) // accounting for sched job delays
		]);
	}

	public void execute(Database.BatchableContext context, List<Contact> contacts) {
		// batch size will be always 1
		Contact contact = contacts[0];
		Logger.setParentLogTransactionId(transactionID);

		try {
			String res = XaCalloutController.createContact(contact);
			contact.XA_Integration_Status__c = res;
			contact.XA_Integrated__c = true;

			Logger.info('Contact successfully integrated').setRecord(contact.Id);
		}
		catch (Exception ex) {
			contact.XA_Integrated__c = false;
			contact.XA_Integration_Status__c = ex.getMessage();

			Logger.error('Contact failed to be integrated', ex).setRecord(contact.Id);
		}
		finally {
			Logger.saveLog();
		}

		update contact;
	}

	public void finish(Database.BatchableContext context) {}


	public void execute(SchedulableContext context) {
		Database.executeBatch(this, MAX_BATCH_SIZE);
	}
}