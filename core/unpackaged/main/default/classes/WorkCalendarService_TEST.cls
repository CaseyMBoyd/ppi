/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @description
 * @date 24.02.2024 <p/>
 *
 */

@IsTest
private class WorkCalendarService_TEST {

	@IsTest
	static void testCalculateDaysOff() {
		// given
		Integer nextDays = 7;

		// when
		List<Date> offDays = new WorkCalendarService().calculateDaysOffForUntil(nextDays);

		// then
		Assert.isTrue(offDays.size() >= 2, 'For a 7 day period we should always have at least 2 days off (Sat, Sun)');
	}

	@IsTest
	static void testCalculateDaysOff_invalidDaysAmount() {
		// given
		Integer negativeAmountOfDays = -7;
		Boolean exThrown = false;

		// when
		try {
			new WorkCalendarService().calculateDaysOffForUntil(negativeAmountOfDays);
			Assert.fail();
		}
		catch(WorkCalendarService.WorkCalendarException ex) {
			exThrown = true;
		}

		// then
		Assert.isTrue(exThrown);
	}
}