@IsTest
private class LeadTriggerHandlerTest {
  @TestSetup
  static void makeData() {
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
  }

  @IsTest
  static void testCloneLead() {
    Lead testLead = [
      SELECT Id, Account__c, Contact__c, Company, LastName, Lead_Queue__c
      FROM Lead
      LIMIT 1
    ];
    Lead newLead = testLead.clone(false, true, false, false);

    Test.startTest();
    insert newLead;
    Test.stopTest();

    Lead testLeadAfterTrigger = [
      SELECT
        Id,
        Name,
        Has_Been_Cloned__c,
        Cloned_To_Lead_Name__c,
        Cloned_From_Lead_Name__c,
        Is_Cloned_Lead__c
      FROM Lead
      WHERE Id = :testLead.Id
    ];
    Lead newLeadAfterTrigger = [
      SELECT
        Id,
        Name,
        Has_Been_Cloned__c,
        Cloned_To_Lead_Name__c,
        Cloned_From_Lead_Name__c,
        Is_Cloned_Lead__c
      FROM Lead
      WHERE Id = :newLead.Id
    ];

    Assert.isTrue(
      testLeadAfterTrigger.Has_Been_Cloned__c,
      'Lead should be marked as having been cloned'
    );
    Assert.isTrue(
      newLeadAfterTrigger.Is_Cloned_Lead__c,
      'New Lead should be marked as a cloned lead.'
    );
  }
}