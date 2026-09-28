@IsTest
private class xStudio_BusinessHoursUtilityTest {
    @IsTest
    static void shouldReturnDifferenceInDates() {

        BusinessHours stdBusinessHours = [SELECT Id FROM BusinessHours WHERE IsDefault = true LIMIT 1];
        
        xStudio_BusinessHoursUtility.DateTimeCompare startDT = new xStudio_BusinessHoursUtility.DateTimeCompare();
        startDT.startDateTime = System.now();
        startDT.endDateTime = System.now() + 1;
        startDT.businessHoursId = stdBusinessHours.Id;

        List<xStudio_BusinessHoursUtility.DateTimeCompare> dateTimes = new List<xStudio_BusinessHoursUtility.DateTimeCompare>();
        dateTimes.add(startDT);

        Test.startTest();
        List<Integer> minutes = xStudio_BusinessHoursUtility.calculateDifference(dateTimes);
        Test.stopTest();
        Assert.isTrue(minutes.size() > 0, 'Utility should return list of minutes.');
    }
}