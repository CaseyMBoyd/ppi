@IsTest
private class xStudio_EmailToLeadTest {
    private class PdfSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request){
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setHeader('Content-Type','application/pdf');
            response.setBodyAsBlob(Blob.valueOf('PDF Content'));
            return response;
        }
    }
    
    static {
        Test.setMock(HttpCalloutMock.class,new PdfSuccessMock());
    }
    
    @TestSetup
    static void makeData() {
        Account testAccount = new Account();
        testAccount.Name = 'Test';
        insert testAccount;
        
        Contact testContact = new Contact();
        testContact.LastName = 'Test';
        testContact.AccountId = testAccount.Id;
        testContact.Email = 'test@test.com';
        insert testContact;
        
        Opportunity testOpp = new Opportunity();
        testOpp.Name = 'Test';
        testOpp.StageName = 'RFQ or PO Received	';
        testOpp.CloseDate = Date.today();
        insert testOpp;
        
        EmailMessage oppEmailMessage = new EmailMessage();
        oppEmailMessage.ToAddress = 'test@test.com';
        oppEmailMessage.FromAddress = 'test@test.com';
        oppEmailMessage.FromName = 'test test';
        oppEmailMessage.Subject = 'test test';
        oppEmailMessage.status = '3';
        oppEmailMessage.HtmlBody = 'test';
        oppEmailMessage.Incoming = false;
        oppEmailMessage.TextBody = 'test';
        oppEmailMessage.MessageIdentifier = 'test@test.com';
        oppEmailMessage.RelatedToId = testOpp.Id;
        insert oppEmailMessage;
        
        Contact emailContact = [
            SELECT Id
            FROM Contact
            WHERE Email = :'test@test.com'
            LIMIT 1
        ];
        // Add Email Message Relation for id of the sender
        EmailMessageRelation emr = new EmailMessageRelation();
        emr.EmailMessageId = oppEmailMessage.id;
        emr.RelationId = emailContact.Id; // user id of the sender
        emr.RelationAddress = 'test@test.com';
        emr.RelationType = 'FromAddress';
        insert emr;
    }
    
    @IsTest
    static void testPulleyDaily() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        email.subject = 'test test';
        email.fromName = 'test test';
        email.fromAddress = 'test@test.com';
        email.htmlBody = 'test';
        email.plainTextBody = 'test';
        email.ccAddresses = new String[]{ 'testcc@test.com' };
            email.toAddresses = new List<String>();
        email.toAddresses.add('test@test.com');
        env.fromAddress = 'test@test.com';
        Test.startTest();
        xStudio_EmailToLeadPulleyDaily pulleyDaily =
            new xStudio_EmailToLeadPulleyDaily();
        pulleyDaily.handleInboundEmail(email, env);
        Test.stopTest();
    }
    
    @IsTest
    static void testIdlerDaily() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        email.subject = 'test test';
        email.fromName = 'test test';
        email.fromAddress = 'test@test.com';
        email.htmlBody = 'test';
        email.plainTextBody = 'test';
        email.ccAddresses = new String[]{ 'testcc@test.com' };
            email.toAddresses = new List<String>();
        email.toAddresses.add('test@test.com');
        env.fromAddress = 'test@test.com';
        Test.startTest();
        xStudio_EmailToLeadIdlerDaily idlerDaily =
            new xStudio_EmailToLeadIdlerDaily();
        idlerDaily.handleInboundEmail(email, env);
        Test.stopTest();
    }
    
    @IsTest
    static void testPulleyProject() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        email.subject = 'test test';
        email.fromName = 'test test';
        email.fromAddress = 'test@test.com';
        email.htmlBody = 'test';
        email.plainTextBody = 'test';
        email.ccAddresses = new String[]{ 'testcc@test.com' };
            email.toAddresses = new List<String>();
        email.toAddresses.add('test@test.com');
        env.fromAddress = 'test@test.com';
        Test.startTest();
        xStudio_EmailToLeadPulleyProject pulleyProject =
            new xStudio_EmailToLeadPulleyProject();
        pulleyProject.handleInboundEmail(email, env);
        Test.stopTest();
    }
    
    @IsTest
    static void testIdlerProject() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        email.subject = 'test test';
        email.fromName = 'test test';
        email.fromAddress = 'test@test.com';
        email.htmlBody = 'test';
        email.plainTextBody = 'test';
        email.ccAddresses = new String[]{ 'testcc@test.com' };
            email.toAddresses = new List<String>();
        email.toAddresses.add('test@test.com');
        env.fromAddress = 'test@test.com';
        Test.startTest();
        xStudio_EmailToLeadIdlerProject idlerProject =
            new xStudio_EmailToLeadIdlerProject();
        idlerProject.handleInboundEmail(email, env);
        Test.stopTest();
    }
    
    @IsTest
    static void testKeyAccounts() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        email.subject = 'test test';
        email.fromName = 'test test';
        email.fromAddress = 'test@test.com';
        email.htmlBody = 'test';
        email.plainTextBody = 'test';
        email.ccAddresses = new String[]{ 'testcc@test.com' };
            email.toAddresses = new List<String>();
        email.toAddresses.add('test@test.com');
        env.fromAddress = 'test@test.com';
        Test.startTest();
        xStudio_EmailToLeadKeyAccounts keyAccounts =
            new xStudio_EmailToLeadKeyAccounts();
        xStudio_EmailToLeadKeyAcct1 keyAcct1 = new xStudio_EmailToLeadKeyAcct1();
        xStudio_EmailToLeadKeyAcct2 keyAcct2 = new xStudio_EmailToLeadKeyAcct2();
        keyAccounts.handleInboundEmail(email, env);
        keyAcct1.handleInboundEmail(email, env);
        keyAcct2.handleInboundEmail(email, env);
        Test.stopTest();
    }
    
    @IsTest
    static void testAttachments() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        email.subject = 'test test';
        email.fromName = 'test test';
        email.fromAddress = 'test@test.com';
        email.htmlBody = 'test';
        email.plainTextBody = 'test';
        email.ccAddresses = new String[]{ 'testcc@test.com' };
            email.toAddresses = new List<String>();
        email.toAddresses.add('test@test.com');
        env.fromAddress = 'test@test.com';
        Messaging.InboundEmail.BinaryAttachment binAttach =
            new Messaging.InboundEmail.BinaryAttachment();
        binAttach.fileName = 'test.txt';
        binAttach.body = Blob.valueOf('test');
        binAttach.mimeTypeSubType = 'text';
        email.binaryAttachments =
            new List<Messaging.InboundEmail.BinaryAttachment>();
        email.binaryAttachments.add(binAttach);
        Test.startTest();
        xStudio_EmailToLeadKeyAccounts keyAccounts =
            new xStudio_EmailToLeadKeyAccounts();
        keyAccounts.handleInboundEmail(email, env);
        Test.stopTest();
    }
    
    @IsTest
    static void testAttachmentsWithExisting() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        email.subject = 'test test';
        email.fromName = 'test test';
        email.fromAddress = 'test@test.com';
        email.ccAddresses = new String[]{ 'testcc@test.com' };
            email.references = new List<String>();
        email.references.add('test@test.com');
        email.toAddresses = new List<String>();
        email.toAddresses.add('test@test.com');
        email.htmlBody = 'test';
        email.plainTextBody = 'test';
        env.fromAddress = 'test@test.com';
        Messaging.InboundEmail.BinaryAttachment binAttach =
            new Messaging.InboundEmail.BinaryAttachment();
        binAttach.fileName = 'test.txt';
        binAttach.body = Blob.valueOf('test');
        binAttach.mimeTypeSubType = 'text';
        email.binaryAttachments =
            new List<Messaging.InboundEmail.BinaryAttachment>();
        email.binaryAttachments.add(binAttach);
        Test.startTest();
        xStudio_EmailToLeadKeyAccounts keyAccounts =
            new xStudio_EmailToLeadKeyAccounts();
        keyAccounts.handleInboundEmail(email, env);
        Test.stopTest();
    }
    
    @IsTest
    static void testNoContactFound() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        email.subject = 'test test';
        email.fromName = 'test test';
        email.fromAddress = 'test1@test.com';
        email.htmlBody = 'test';
        email.plainTextBody = 'test';
        email.ccAddresses = new String[]{ 'testcc@test.com' };
            email.toAddresses = new List<String>();
        email.toAddresses.add('test@test.com');
        env.fromAddress = 'test1@test.com';
        Test.startTest();
        xStudio_EmailToLeadKeyAccounts keyAccounts =
            new xStudio_EmailToLeadKeyAccounts();
        keyAccounts.handleInboundEmail(email, env);
        Test.stopTest();
    }
    
    @IsTest
    static void testPulleyDailyExistingMessageLink() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        email.subject = 'test test';
        email.fromName = 'test test';
        email.fromAddress = 'test@test.com';
        email.ccAddresses = new String[]{ 'testcc@test.com' };
            email.references = new List<String>();
        email.references.add('test@test.com');
        email.toAddresses = new List<String>();
        email.toAddresses.add('test@test.com');
        email.htmlBody = 'test';
        email.plainTextBody = 'test';
        env.fromAddress = 'test@test.com';
        Test.startTest();
        xStudio_EmailToLeadPulleyDaily pulleyDaily =
            new xStudio_EmailToLeadPulleyDaily();
        pulleyDaily.handleInboundEmail(email, env);
        Test.stopTest();
    }
    
    @IsTest
    static void testIdlerDailyExistingMessageLink() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        email.subject = 'test test';
        email.fromName = 'test test';
        email.fromAddress = 'test@test.com';
        email.ccAddresses = new String[]{ 'testcc@test.com' };
            email.references = new List<String>();
        email.references.add('test@test.com');
        email.toAddresses = new List<String>();
        email.toAddresses.add('test@test.com');
        email.htmlBody = 'test';
        email.plainTextBody = 'test';
        env.fromAddress = 'test@test.com';
        Test.startTest();
        xStudio_EmailToLeadIdlerDaily idlerDaily =
            new xStudio_EmailToLeadIdlerDaily();
        idlerDaily.handleInboundEmail(email, env);
        Test.stopTest();
    }
    
    @IsTest
    static void testPulleyProjectExistingMessageLink() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        email.subject = 'test test';
        email.fromName = 'test test';
        email.fromAddress = 'test@test.com';
        email.ccAddresses = new String[]{ 'testcc@test.com' };
            email.references = new List<String>();
        email.references.add('test@test.com');
        email.toAddresses = new List<String>();
        email.toAddresses.add('test@test.com');
        email.htmlBody = 'test';
        email.plainTextBody = 'test';
        env.fromAddress = 'test@test.com';
        Test.startTest();
        xStudio_EmailToLeadPulleyProject pulleyProject =
            new xStudio_EmailToLeadPulleyProject();
        pulleyProject.handleInboundEmail(email, env);
        Test.stopTest();
    }
    
    @IsTest
    static void testIdlerProjectExistingMessageLink() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        email.subject = 'test test';
        email.fromName = 'test test';
        email.fromAddress = 'test@test.com';
        email.ccAddresses = new String[]{ 'testcc@test.com' };
            email.references = new List<String>();
        email.references.add('test@test.com');
        email.toAddresses = new List<String>();
        email.toAddresses.add('test@test.com');
        email.htmlBody = 'test';
        email.plainTextBody = 'test';
        env.fromAddress = 'test@test.com';
        Test.startTest();
        xStudio_EmailToLeadIdlerProject idlerProject =
            new xStudio_EmailToLeadIdlerProject();
        idlerProject.handleInboundEmail(email, env);
        Test.stopTest();
    }
    
    @IsTest
    static void testKeyAccountsExistingMessageLink() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        email.subject = 'test test';
        email.fromName = 'test test';
        email.fromAddress = 'test@test.com';
        email.ccAddresses = new String[]{ 'testcc@test.com' };
            email.references = new List<String>();
        email.references.add('test@test.com');
        email.toAddresses = new List<String>();
        email.toAddresses.add('test@test.com');
        email.htmlBody = 'test';
        email.plainTextBody = 'test';
        env.fromAddress = 'test@test.com';
        Test.startTest();
        xStudio_EmailToLeadKeyAccounts keyAccounts =
            new xStudio_EmailToLeadKeyAccounts();
        xStudio_EmailToLeadKeyAcct1 keyAcct1 = new xStudio_EmailToLeadKeyAcct1();
        xStudio_EmailToLeadKeyAcct2 keyAcct2 = new xStudio_EmailToLeadKeyAcct2();
        keyAccounts.handleInboundEmail(email, env);
        keyAcct1.handleInboundEmail(email, env);
        keyAcct2.handleInboundEmail(email, env);
        Test.stopTest();
    }
    
    @IsTest
    static void testOrderSupport() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        email.subject = 'test test';
        email.fromName = 'test test';
        email.fromAddress = 'test@test.com';
        email.htmlBody = 'test';
        email.plainTextBody = 'test';
        email.ccAddresses = new String[]{ 'testcc@test.com' };
            email.toAddresses = new List<String>();
        email.toAddresses.add('test@test.com');
        env.fromAddress = 'test@test.com';
        Test.startTest();
        xStudio_EmailToLeadOrderSupport orderSupport =
            new xStudio_EmailToLeadOrderSupport();
        orderSupport.handleInboundEmail(email, env);
        Test.stopTest();
    }
    
    @IsTest
    static void testOrderSupportExistingMessageLink() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        email.subject = 'test test';
        email.fromName = 'test test';
        email.fromAddress = 'test@test.com';
        email.ccAddresses = new String[]{ 'testcc@test.com' };
            email.references = new List<String>();
        email.references.add('test@test.com');
        email.toAddresses = new List<String>();
        email.toAddresses.add('test@test.com');
        email.htmlBody = 'test';
        email.plainTextBody = 'test';
        env.fromAddress = 'test@test.com';
        Test.startTest();
        xStudio_EmailToLeadOrderSupport orderSupport =
            new xStudio_EmailToLeadOrderSupport();
        orderSupport.handleInboundEmail(email, env);
        Test.stopTest();
    }
    
    @IsTest
    static void testInsideSalesTempInbox() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        email.subject = 'test test';
        email.fromName = 'test test';
        email.fromAddress = 'test@test.com';
        email.htmlBody = 'test';
        email.plainTextBody = 'test';
        email.ccAddresses = new String[]{ 'testcc@test.com' };
            email.toAddresses = new List<String>();
        email.toAddresses.add('test@test.com');
        env.fromAddress = 'test@test.com';
        Test.startTest();
        xStudio_EmailToLeadInsideSalesTempInbox insideSalesTempInbox =
            new xStudio_EmailToLeadInsideSalesTempInbox();
        xStudio_EmailToLeadFloater floaterInbox = new xStudio_EmailToLeadFloater();
        floaterInbox.handleInboundEmail(email, env);
        insideSalesTempInbox.handleInboundEmail(email, env);
        Test.stopTest();
    }
    
    @IsTest
    static void testInsideSalesTempInboxExistingMessageLink() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        email.subject = 'test test';
        email.fromName = 'test test';
        email.fromAddress = 'test@test.com';
        email.ccAddresses = new String[]{ 'testcc@test.com' };
            email.references = new List<String>();
        email.references.add('test@test.com');
        email.toAddresses = new List<String>();
        email.toAddresses.add('test@test.com');
        email.htmlBody = 'test';
        email.plainTextBody = 'test';
        env.fromAddress = 'test@test.com';
        Test.startTest();
        xStudio_EmailToLeadInsideSalesTempInbox insideSalesTempInbox =
            new xStudio_EmailToLeadInsideSalesTempInbox();
        insideSalesTempInbox.handleInboundEmail(email, env);
        Test.stopTest();
    }
    
    @IsTest
    static void testISASameDay() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        email.subject = 'test test';
        email.fromName = 'test test';
        email.fromAddress = 'test@test.com';
        email.htmlBody = 'test';
        email.plainTextBody = 'test';
        email.ccAddresses = new String[]{ 'testcc@test.com' };
            email.toAddresses = new List<String>();
        email.toAddresses.add('test@test.com');
        env.fromAddress = 'test@test.com';
        Test.startTest();
        xStudio_EmailToLeadISASameDay isaSameDay =
            new xStudio_EmailToLeadISASameDay();
        isaSameDay.handleInboundEmail(email, env);
        Test.stopTest();
    }
    
    @IsTest
    static void testISASameDayExistingMessageLink() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        email.subject = 'test test';
        email.fromName = 'test test';
        email.fromAddress = 'test@test.com';
        email.ccAddresses = new String[]{ 'testcc@test.com' };
            email.references = new List<String>();
        email.references.add('test@test.com');
        email.toAddresses = new List<String>();
        email.toAddresses.add('test@test.com');
        email.htmlBody = 'test';
        email.plainTextBody = 'test';
        env.fromAddress = 'test@test.com';
        Test.startTest();
        xStudio_EmailToLeadISASameDay isaSameDay =
            new xStudio_EmailToLeadISASameDay();
        isaSameDay.handleInboundEmail(email, env);
        Test.stopTest();
    }
    
    @IsTest
    static void testEast() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        email.subject = 'test test';
        email.fromName = 'test test';
        email.fromAddress = 'test@test.com';
        email.htmlBody = 'test';
        email.plainTextBody = 'test';
        email.ccAddresses = new String[]{ 'testcc@test.com' };
            email.toAddresses = new List<String>();
        email.toAddresses.add('test@test.com');
        env.fromAddress = 'test@test.com';
        Test.startTest();
        xStudio_EmailToLeadEast4 east4 = new xStudio_EmailToLeadEast4();
        xStudio_EmailToLeadEast11 east11 = new xStudio_EmailToLeadEast11();
        xStudio_EmailToLeadEast21 east21 = new xStudio_EmailToLeadEast21();
        xStudio_EmailToLeadEast33 east33 = new xStudio_EmailToLeadEast33();
        east4.handleInboundEmail(email, env);
        east11.handleInboundEmail(email, env);
        east21.handleInboundEmail(email, env);
        east33.handleInboundEmail(email, env);
        Test.stopTest();
    }
    
    @IsTest
    static void testEastExistingMessageLink() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        email.subject = 'test test';
        email.fromName = 'test test';
        email.fromAddress = 'test@test.com';
        email.ccAddresses = new String[]{ 'testcc@test.com' };
            email.references = new List<String>();
        email.references.add('test@test.com');
        email.toAddresses = new List<String>();
        email.toAddresses.add('test@test.com');
        email.htmlBody = 'test';
        email.plainTextBody = 'test';
        env.fromAddress = 'test@test.com';
        Test.startTest();
        xStudio_EmailToLeadEast4 east4 = new xStudio_EmailToLeadEast4();
        xStudio_EmailToLeadEast11 east11 = new xStudio_EmailToLeadEast11();
        xStudio_EmailToLeadEast21 east21 = new xStudio_EmailToLeadEast21();
        xStudio_EmailToLeadEast33 east33 = new xStudio_EmailToLeadEast33();
        east4.handleInboundEmail(email, env);
        east11.handleInboundEmail(email, env);
        east21.handleInboundEmail(email, env);
        east33.handleInboundEmail(email, env);
        Test.stopTest();
    }
    
    @IsTest
    static void testWest() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        email.subject = 'test test';
        email.fromName = 'test test';
        email.fromAddress = 'test@test.com';
        email.htmlBody = 'test';
        email.plainTextBody = 'test';
        email.ccAddresses = new String[]{ 'testcc@test.com' };
            email.toAddresses = new List<String>();
        email.toAddresses.add('test@test.com');
        env.fromAddress = 'test@test.com';
        Test.startTest();
        xStudio_EmailToLeadWest15 west15 = new xStudio_EmailToLeadWest15();
        xStudio_EmailToLeadWest26 west26 = new xStudio_EmailToLeadWest26();
        xStudio_EmailToLeadWest35 west35 = new xStudio_EmailToLeadWest35();
        west15.handleInboundEmail(email, env);
        west26.handleInboundEmail(email, env);
        west35.handleInboundEmail(email, env);
        Test.stopTest();
    }
    
    @IsTest
    static void testWestExistingMessageLink() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        email.subject = 'test test';
        email.fromName = 'test test';
        email.fromAddress = 'test@test.com';
        email.ccAddresses = new String[]{ 'testcc@test.com' };
            email.references = new List<String>();
        email.references.add('test@test.com');
        email.toAddresses = new List<String>();
        email.toAddresses.add('test@test.com');
        email.htmlBody = 'test';
        email.plainTextBody = 'test';
        env.fromAddress = 'test@test.com';
        Test.startTest();
        xStudio_EmailToLeadWest15 west15 = new xStudio_EmailToLeadWest15();
        xStudio_EmailToLeadWest26 west26 = new xStudio_EmailToLeadWest26();
        xStudio_EmailToLeadWest35 west35 = new xStudio_EmailToLeadWest35();
        west15.handleInboundEmail(email, env);
        west26.handleInboundEmail(email, env);
        west35.handleInboundEmail(email, env);
        Test.stopTest();
    }
    
    @IsTest
    static void testCentral() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        email.subject = 'test test';
        email.fromName = 'test test';
        email.fromAddress = 'test@test.com';
        email.htmlBody = 'test';
        email.plainTextBody = 'test';
        email.ccAddresses = new String[]{ 'testcc@test.com' };
            email.toAddresses = new List<String>();
        email.toAddresses.add('test@test.com');
        env.fromAddress = 'test@test.com';
        Test.startTest();
        xStudio_EmailToLeadCentral3 central3 = new xStudio_EmailToLeadCentral3();
        xStudio_EmailToLeadCentral9 central9 = new xStudio_EmailToLeadCentral9();
        xStudio_EmailToLeadCentral14 central14 = new xStudio_EmailToLeadCentral14();
        xStudio_EmailToLeadCentral16 central16 = new xStudio_EmailToLeadCentral16();
        xStudio_EmailToLeadCentral24 central24 = new xStudio_EmailToLeadCentral24();
        central3.handleInboundEmail(email, env);
        central9.handleInboundEmail(email, env);
        central14.handleInboundEmail(email, env);
        central16.handleInboundEmail(email, env);
        central24.handleInboundEmail(email, env);
        Test.stopTest();
    }
    
    @IsTest
    static void testCentralExistingMessageLink() {
        Messaging.InboundEmail email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();
        email.subject = 'test test';
        email.fromName = 'test test';
        email.fromAddress = 'test@test.com';
        email.ccAddresses = new String[]{ 'testcc@test.com' };
            email.references = new List<String>();
        email.references.add('test@test.com');
        email.toAddresses = new List<String>();
        email.toAddresses.add('test@test.com');
        email.htmlBody = 'test';
        email.plainTextBody = 'test';
        env.fromAddress = 'test@test.com';
        Test.startTest();
        xStudio_EmailToLeadCentral3 central3 = new xStudio_EmailToLeadCentral3();
        xStudio_EmailToLeadCentral9 central9 = new xStudio_EmailToLeadCentral9();
        xStudio_EmailToLeadCentral14 central14 = new xStudio_EmailToLeadCentral14();
        xStudio_EmailToLeadCentral16 central16 = new xStudio_EmailToLeadCentral16();
        xStudio_EmailToLeadCentral24 central24 = new xStudio_EmailToLeadCentral24();
        central3.handleInboundEmail(email, env);
        central9.handleInboundEmail(email, env);
        central14.handleInboundEmail(email, env);
        central16.handleInboundEmail(email, env);
        central24.handleInboundEmail(email, env);
        Test.stopTest();
    }
}