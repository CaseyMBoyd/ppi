@IsTest
private class xStudio_LeadConversionTest {
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

        List<Lead> leadList = new List<Lead>();
        leadList.add(testLead);

        Test.startTest();
        List<Id> newOpportunityIds = xStudio_LeadConversion.convertLeadsToOpportunitys(leadList);
        Test.stopTest();

        Assert.isTrue(newOpportunityIds.size() > 0, 'Opportunity should have been created.');
    }
}