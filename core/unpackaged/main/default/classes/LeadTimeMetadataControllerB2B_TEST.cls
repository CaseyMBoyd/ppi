/**
 * @description Test suite for LeadTimeMetadataControllerB2B.
 * Custom Metadata records are accessible in tests without @TestSetup.
 * Target: minimum 85% code coverage.
 */
@IsTest
private class LeadTimeMetadataControllerB2B_TEST {

    @IsTest
    static void testGetLeadTimeGuidanceRulesReturnsData() {
        Test.startTest();
        List<Lead_Time_Guidance__mdt> rules = LeadTimeMetadataControllerB2B.getLeadTimeGuidanceRules();
        Test.stopTest();

        Assert.isNotNull(rules, 'Result list must never be null');

        for (Lead_Time_Guidance__mdt rule : rules) {
            Assert.isTrue(rule.Is_Fallback__c != null || rule.Location_Code__c != null,
                'Each rule must have at minimum a Location Code or Fallback flag'
            );
        }
    }

}