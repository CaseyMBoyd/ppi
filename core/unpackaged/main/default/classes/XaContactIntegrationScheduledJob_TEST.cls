/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @date 15.03.2024
 * @description Test suite
 *
 */

@IsTest
private class XaContactIntegrationScheduledJob_TEST {
	@IsTest
	static void testScheduling() {
		Assert.isNotNull(XaContactIntegrationScheduledJob.scheduleToRunHourly());
	}

	@IsTest
	static void testBatch() {
		// given
		Contact contact = XaCalloutController_TEST.createContact();

		String mockedResponseBody = '"Successfully created contact"';
		Test.setMock(HttpCalloutMock.class, new XaCalloutController_TEST.HttpMock(201, mockedResponseBody));

		// when
		Test.startTest();
		Database.executeBatch(new XaContactIntegrationScheduledJob(), 1);
		Test.stopTest();

		// then
		Contact updated = [
			SELECT Id,
				XA_Integration_Status__c,
				XA_Integrated__c
			FROM Contact
			WHERE Id = :contact.Id
		];

		Assert.isNotNull(updated.XA_Integrated__c);
		Assert.areEqual(mockedResponseBody, updated.XA_Integration_Status__c);
	}
}