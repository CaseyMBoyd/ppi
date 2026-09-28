/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @description
 * @date 24.02.2024 <p/>
 * @test WorkCalendarService_TEST
 *
 */

public with sharing class WorkCalendarService {

	private final BusinessHours hours;

	public WorkCalendarService() {
		this([
			SELECT Id,
				TimeZoneSidKey
			FROM BusinessHours
			WHERE IsDefault = TRUE
			LIMIT 1
		]);
	}
	public WorkCalendarService(BusinessHours hours) {
		this.hours = hours;
	}

	public List<Date> calculateDaysOffForUntil(Integer days) {
		if (days == null || days < 1) {
			throw new WorkCalendarException('Passed "Days" amount must be greater or equal 1');
		}
		return calculateDaysOffForUntil(Datetime.now().dateGmt().addDays(days));
	}

	public List<Date> calculateDaysOffForUntil(Date maxDate) {
		List<Date> daysOff = new List<Date>();
		Datetime currentDate = Datetime.now();

		TimeZone tz = TimeZone.getTimeZone(this.hours.TimeZoneSidKey);
		Integer offset = tz.getOffset(Datetime.now()) / 1000;
		currentDate = currentDate.addSeconds(offset);
		Time noon = Time.newInstance(12, 0, 0, 0);
		currentDate = Datetime.newInstance(currentDate.dateGMT(), noon);

		while (currentDate <= maxDate) {
			if (!BusinessHours.isWithin(this.hours.Id, currentDate)) {
				daysOff.add(currentDate.date());
			}
			currentDate = currentDate.addDays(1);
		}

		return daysOff;
	}

	public class WorkCalendarException extends Exception {
	}
}