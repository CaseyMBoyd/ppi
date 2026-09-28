@IsTest
private class xStudio_EmailToLeadOICTest {
  @TestSetup
  static void makeData() {
    getOrCreateNewLeadsQueueId();
    createExistingEmailMessage('existing-oic-message-id');
  }

  @IsTest
  static void shouldCreateOICLeadWhenNoExistingMessageFound() {
    Messaging.InboundEmail email =
      makeEmail('oic.customer@example.com', 'OIC inquiry');

    Test.startTest();
    Messaging.InboundEmailResult result =
      new xStudio_EmailToLeadOIC().handleInboundEmail(
        email,
        makeEnvelope(email.fromAddress)
      );
    Test.stopTest();

    Assert.isTrue(result.success, 'Inbound email handling should succeed.');

    Lead createdLead = [
      SELECT Email, LeadSource, Lead_Queue__c, Customer_Request_Subject__c
      FROM Lead
      WHERE Email = :email.fromAddress
      LIMIT 1
    ];
    Assert.areEqual(email.fromAddress, createdLead.Email);
    Assert.areEqual('Email', createdLead.LeadSource);
    Assert.areEqual('OIC Queue', createdLead.Lead_Queue__c);
    Assert.areEqual(email.subject, createdLead.Customer_Request_Subject__c);
  }

  @IsTest
  static void shouldLinkOICReplyWhenExistingMessageReferenceFound() {
    Messaging.InboundEmail email =
      makeEmail('existing.oic.customer@example.com', 'OIC reply');
    email.references = new List<String>{ 'existing-oic-message-id' };

    Test.startTest();
    Messaging.InboundEmailResult result =
      new xStudio_EmailToLeadOIC().handleInboundEmail(
        email,
        makeEnvelope(email.fromAddress)
      );
    Test.stopTest();

    assertReplyLinked(
      result,
      email,
      'existing-oic-message-id'
    );
  }

  private static void assertReplyLinked(
    Messaging.InboundEmailResult result,
    Messaging.InboundEmail email,
    String existingMessageId
  ) {
    Assert.isTrue(result.success, 'Inbound email handling should succeed.');
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Lead WHERE Email = :email.fromAddress],
      'A reply to an existing message should not create a new Lead.'
    );

    EmailMessage existingEmailMessage = [
      SELECT RelatedToId
      FROM EmailMessage
      WHERE MessageIdentifier = :existingMessageId
      LIMIT 1
    ];
    EmailMessage linkedEmailMessage = [
      SELECT FromAddress, Incoming, RelatedToId, Subject
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

  private static void createExistingEmailMessage(String messageIdentifier) {
    Opportunity testOpportunity = new Opportunity(
      Name = 'OIC Email Reply Opportunity',
      StageName = 'RFQ or PO Received	',
      CloseDate = Date.today()
    );
    insert testOpportunity;

    insert new EmailMessage(
      ToAddress = 'oic@example.com',
      FromAddress = 'existing.oic.customer@example.com',
      FromName = 'Existing OIC Customer',
      Subject = 'Existing OIC message',
      Status = '3',
      HtmlBody = 'Existing body',
      Incoming = false,
      TextBody = 'Existing body',
      MessageIdentifier = messageIdentifier,
      RelatedToId = testOpportunity.Id
    );
  }

  private static Messaging.InboundEmail makeEmail(
    String fromAddress,
    String subject
  ) {
    Messaging.InboundEmail email = new Messaging.InboundEmail();
    email.subject = subject;
    email.fromName = 'Test Customer';
    email.fromAddress = fromAddress;
    email.htmlBody = 'Please help with this request.';
    email.plainTextBody = 'Please help with this request.';
    email.ccAddresses = new String[]{ 'copy@example.com' };
    email.toAddresses = new List<String>{ 'oic@example.com' };
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