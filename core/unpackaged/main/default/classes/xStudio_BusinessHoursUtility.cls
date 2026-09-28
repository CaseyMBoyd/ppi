global class xStudio_BusinessHoursUtility {
  @InvocableMethod(
    label='Calculate time with business hours'
    description='Calculates time between two datetimes taking into account business hours.'
    category='Business Hours Utilities'
  )
  global static List<Integer> calculateDifference(
    List<DateTimeCompare> datetimes
  ) {
    List<Integer> differences = new List<Integer>();
    for (DateTimeCompare d : datetimes) {
      Long milliseconds =
        BusinessHours.diff(d.businessHoursId, d.startDateTime, d.endDateTime);

      Long minutes = milliseconds / 60000;

      differences.add(minutes.intValue());
    }
    return differences;
  }

  global class DateTimeCompare {
    @InvocableVariable(required=true label='Start date/time')
    global DateTime startDateTime;

    @InvocableVariable(required=true label='End date/time')
    global DateTime endDateTime;

    @InvocableVariable(required=true label='Business hours Id to use')
    global String businessHoursId;
  }
}