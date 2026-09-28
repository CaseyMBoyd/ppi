@IsTest
private class CopyClonedLeadRelatedRecordsTest {
  @TestSetup
  static void makeData() {
    Lead sourceLead = new Lead(
      Company = 'Source Company',
      LastName = 'Source Lead',
      Lead_Queue__c = 'Pulley Daily'
    );
    insert sourceLead;
    
      EmailMessage email = new EmailMessage(
          Subject = 'Test Email',
          HtmlBody = '<p>Test Body</p>',
          TextBody = 'Test Body',
          Headers = 'Header',
          FromName = 'Test User',
          FromAddress = 'test@test.com',
          ToAddress = 'recipient@test.com',
          Incoming = true,
          Status = '3',
          MessageDate = System.now()
      );
      insert email;
      
      insert new EmailMessageRelation(
          EmailMessageId = email.Id,
          RelationId = sourceLead.Id,
          RelationType = 'ToAddress',
          RelationAddress = 'recipient@test.com'
      );
      
    ContentVersion contentVersion = new ContentVersion(
      Title = 'Lead File',
      PathOnClient = 'LeadFile.txt',
      VersionData = Blob.valueOf('Lead file body')
    );
    insert contentVersion;

    Id contentDocumentId = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :contentVersion.Id
    ].ContentDocumentId;

    insert new ContentDocumentLink(
      ContentDocumentId = contentDocumentId,
      LinkedEntityId = sourceLead.Id,
      ShareType = 'V',
      Visibility = 'AllUsers'
    );

    insert new Task(
      WhoId = sourceLead.Id,
      Subject = 'Source Task',
      Status = 'Not Started',
      Priority = 'Normal',
      ActivityDate = Date.today()
    );

    insert new Event(
      WhoId = sourceLead.Id,
      Subject = 'Source Event',
      StartDateTime = System.now().addDays(1),
      EndDateTime = System.now().addDays(1).addHours(1)
    );
  }

  @IsTest
  static void copiesFilesTasksAndEventsToClonedLead() {
    Lead sourceLead = [
      SELECT Id, Company, LastName, Lead_Queue__c
      FROM Lead
      LIMIT 1
    ];
    Test.startTest();
    Lead clonedLead = sourceLead.clone(false, true, false, false);
    insert clonedLead;
    Test.stopTest();

    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM ContentDocumentLink
        WHERE LinkedEntityId = :clonedLead.Id
      ],
      'The cloned Lead should be linked to the source Lead file.'
    );
    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM Task
        WHERE WhoId = :clonedLead.Id AND Subject = 'Source Task'
      ],
      'The source Lead task should be copied to the cloned Lead.'
    );
    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM Event
        WHERE WhoId = :clonedLead.Id AND Subject = 'Source Event'
      ],
      'The source Lead event should be copied to the cloned Lead.'
    );
      List<EmailMessageRelation> clonedRelations = [SELECT EmailMessageId FROM EmailMessageRelation WHERE RelationId = :clonedLead.Id];
      
      System.assertEquals(1,clonedRelations.size(),'Email Message Relation should be copied to the cloned Lead.');
      
      EmailMessage clonedEmail = [SELECT Subject,HtmlBody,TextBody, FromAddress,ToAddress,Incoming,Status
                                  FROM EmailMessage WHERE Id = :clonedRelations[0].EmailMessageId];
      
      System.assertEquals('Test Email', clonedEmail.Subject);
      System.assertEquals('<p>Test Body</p>', clonedEmail.HtmlBody);
      System.assertEquals('Test Body', clonedEmail.TextBody);
      System.assertEquals('test@test.com', clonedEmail.FromAddress);
      System.assertEquals('recipient@test.com', clonedEmail.ToAddress);
      System.assertEquals(true, clonedEmail.Incoming);
      System.assertEquals('3', clonedEmail.Status);  
  }

  @IsTest
  static void ignoresLeadsWithoutSourceLead() {
    Lead standaloneLead = new Lead(
      Company = 'Standalone Company',
      LastName = 'Standalone Lead',
      Lead_Queue__c = 'Pulley Daily'
    );
    insert standaloneLead;

    Test.startTest();
    CopyClonedLeadRelatedRecords.copyRelatedRecords(new List<Lead>{ standaloneLead });
    Test.stopTest();

    Assert.areEqual(
      0,
      [
        SELECT COUNT()
        FROM Task
        WHERE WhoId = :standaloneLead.Id
      ],
      'A non-cloned Lead should not receive copied activities.'
    );
  }
}