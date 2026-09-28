@IsTest
private class xStudio_EmailToLeadeCommerceTest {
  @TestSetup
  static void makeData() {
    getOrCreateNewLeadsQueueId();

    Account testAccount = new Account(Name = 'Test Account');
    insert testAccount;

    Contact testContact = new Contact(
      LastName = 'Contact',
      AccountId = testAccount.Id,
      Email = 'existing@example.com'
    );
    insert testContact;

    Opportunity testOpportunity = new Opportunity(
      Name = 'Test Opportunity',
      StageName = 'RFQ or PO Received	',
      CloseDate = Date.today()
    );
    insert testOpportunity;

    EmailMessage existingEmailMessage = new EmailMessage(
      ToAddress = 'existing@example.com',
      FromAddress = 'existing@example.com',
      FromName = 'Existing Contact',
      Subject = 'Existing message',
      Status = '3',
      HtmlBody = 'Existing body',
      Incoming = false,
      TextBody = 'Existing body',
      MessageIdentifier = 'existing-message-id',
      RelatedToId = testOpportunity.Id
    );
    insert existingEmailMessage;
  }

  @IsTest
  static void shouldCreateECommerceLeadWhenNoExistingMessageFound() {
    Messaging.InboundEmail email = makeEmail('new.customer@example.com');
    Messaging.InboundEnvelope env = makeEnvelope(email.fromAddress);

    Test.startTest();
    Messaging.InboundEmailResult result =
      new xStudio_EmailToLeadeCommerce().handleInboundEmail(email, env);
    Test.stopTest();

    Assert.isTrue(result.success, 'Inbound email handling should succeed.');

    Lead createdLead = [
      SELECT Id, Email, LeadSource, Lead_Queue__c, Customer_Request_Subject__c
      FROM Lead
      WHERE Email = :email.fromAddress
      LIMIT 1
    ];
    Assert.areEqual('Email', createdLead.LeadSource);
    Assert.areEqual('eCommerce', createdLead.Lead_Queue__c);
    Assert.areEqual(email.subject, createdLead.Customer_Request_Subject__c);
  }

  @IsTest
  static void shouldLinkReplyWhenExistingMessageReferenceFound() {
    Messaging.InboundEmail email = makeEmail('existing@example.com');
    email.references = new List<String>{ 'existing-message-id' };
    Messaging.InboundEnvelope env = makeEnvelope(email.fromAddress);

    EmailMessage existingEmailMessage = [
      SELECT RelatedToId
      FROM EmailMessage
      WHERE MessageIdentifier = 'existing-message-id'
      LIMIT 1
    ];

    Test.startTest();
    Messaging.InboundEmailResult result =
      new xStudio_EmailToLeadeCommerce().handleInboundEmail(email, env);
    Test.stopTest();

    Assert.isTrue(result.success, 'Inbound email handling should succeed.');
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Lead WHERE Email = :email.fromAddress],
      'A reply to an existing message should not create a new Lead.'
    );

    EmailMessage linkedEmailMessage = [
      SELECT Id, FromAddress, Incoming, RelatedToId, Subject
      FROM EmailMessage
      WHERE MessageIdentifier = :email.messageId
      LIMIT 1
    ];
    Assert.areEqual(email.fromAddress, linkedEmailMessage.FromAddress);
    Assert.isTrue(linkedEmailMessage.Incoming);
    Assert.areEqual(
      existingEmailMessage.RelatedToId,
      linkedEmailMessage.RelatedToId
    );
    Assert.areEqual(email.subject, linkedEmailMessage.Subject);
  }

  private static Messaging.InboundEmail makeEmail(String fromAddress) {
    Messaging.InboundEmail email = new Messaging.InboundEmail();
    email.subject = 'eCommerce inquiry';
    email.fromName = 'Test Customer';
    email.fromAddress = fromAddress;
    email.htmlBody = 'Can you help with this order?';
    email.plainTextBody = 'Can you help with this order?';
    email.ccAddresses = new String[]{ 'copy@example.com' };
    email.toAddresses = new List<String>{ 'ecommerce@example.com' };
    email.messageId = 'message-' + fromAddress;
    return email;
  }

  private static Messaging.InboundEnvelope makeEnvelope(String fromAddress) {
    Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
    env.fromAddress = fromAddress;
    return env;
  }

  private static Id getOrCreateNewLeadsQueueId() {
    List<Group> queues = [
      SELECT Id
      FROM Group
      WHERE Type = 'Queue' AND Name = 'New Leads'
      LIMIT 1
    ];

    Id queueId;
    if (queues.isEmpty()) {
      Group newLeadsQueue = new Group(
        Name = 'New Leads',
        DeveloperName = 'New_Leads',
        Type = 'Queue'
      );
      insert newLeadsQueue;
      queueId = newLeadsQueue.Id;
    } else {
      queueId = queues[0].Id;
    }

    if (
      [
        SELECT COUNT()
        FROM QueueSObject
        WHERE QueueId = :queueId AND SObjectType = 'Lead'
      ] == 0
    ) {
      insert new QueueSObject(
        QueueId = queueId,
        SObjectType = 'Lead'
      );
    }

    return queueId;
  }
}