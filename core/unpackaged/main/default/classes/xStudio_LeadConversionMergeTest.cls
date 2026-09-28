@IsTest
private class xStudio_LeadConversionMergeTest {
    @IsTest
    static void shouldReturnConvertedLead() {
        Account testAccount = new Account();
        testAccount.Name = 'Test';
        insert testAccount;

        Contact testContact = new Contact();
        testContact.LastName = 'Test';
        testContact.AccountId = testAccount.Id;
        insert testContact;
        
        Lead testLead = new Lead();
        testLead.Account__c = testAccount.Id;
        testLead.Contact__c = testContact.Id;
        testLead.Company = 'Test';
        testLead.LastName = 'Test';
        testLead.Lead_Queue__c = 'Pulley Daily';
        insert testLead;

        Opportunity opp = new Opportunity();
        opp.Name = 'Test Opp';
        opp.StageName = 'Prospecting';
        opp.CloseDate = Date.today();
        insert opp;

        xStudio_LeadConversionMerge.LeadMergeConversionRequest lmcr = new xStudio_LeadConversionMerge.LeadMergeConversionRequest();
        lmcr.lead = testLead;
        lmcr.opportunity = opp.Id;
        List<xStudio_LeadConversionMerge.LeadMergeConversionRequest> leadList = new List<xStudio_LeadConversionMerge.LeadMergeConversionRequest>();
        leadList.add(lmcr);

        Test.startTest();
        xStudio_LeadConversionMerge.mergeLeadsToOpportunities(leadList);
        Test.stopTest();
    }

    @IsTest
    static void shouldThrowWhenLeadNotTiedToAccountAndContact() {
        Lead testLead = new Lead();
        testLead.Company = 'Test';
        testLead.LastName = 'Test';
        testLead.Lead_Queue__c = 'Pulley Daily';
        insert testLead;

        Opportunity opp = new Opportunity();
        opp.Name = 'Test Opp';
        opp.StageName = 'Prospecting';
        opp.CloseDate = Date.today();
        insert opp;

        xStudio_LeadConversionMerge.LeadMergeConversionRequest lmcr = new xStudio_LeadConversionMerge.LeadMergeConversionRequest();
        lmcr.lead = testLead;
        lmcr.opportunity = opp.Id;
        List<xStudio_LeadConversionMerge.LeadMergeConversionRequest> leadList = new List<xStudio_LeadConversionMerge.LeadMergeConversionRequest>();
        leadList.add(lmcr);

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            xStudio_LeadConversionMerge.mergeLeadsToOpportunities(leadList);
        } catch (xStudio_LeadConversionMerge.LeadMergeConversionException e) {
            exceptionThrown = true;
            System.assertEquals('Select an existing Account & Contact before merge/convert.', e.getMessage());
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Expected LeadMergeConversionException when Lead is not tied to an Account and Contact');
        System.assertEquals(false, [SELECT IsConverted FROM Lead WHERE Id = :testLead.Id].IsConverted);
    }
}