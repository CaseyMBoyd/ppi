@IsTest
public class EmailMessageFileCopyActionTest {
    @TestSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        EmailMessage sourceEmail = new EmailMessage(
            Subject = 'Source Email',
            TextBody = 'Test Body',
            FromAddress = 'test@test.com',
            ToAddress = 'user@test.com',
            Incoming = true,
            Status = '3',
            RelatedToId = acc.Id,
            MessageIdentifier = 'TEST-MESSAGE-ID-123'
        );
        insert sourceEmail;
        EmailMessage targetEmail = new EmailMessage(
            Subject = 'Target Email',
            TextBody = 'Test Body',
            FromAddress = 'test@test.com',
            ToAddress = 'user@test.com',
            Incoming = true,
            Status = '3',
            RelatedToId = acc.Id,
            MessageIdentifier = 'TEST-MESSAGE-ID-123'
        );
        insert targetEmail;
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Test File Body')
        );
        insert cv;
        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = sourceEmail.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
    }
    @IsTest
    static void testCopyEmailMessageFiles() {
        EmailMessage sourceEmail = [SELECT Id, MessageIdentifier FROM EmailMessage WHERE Subject = 'Source Email' LIMIT 1];
        EmailMessage targetEmail = [SELECT Id, MessageIdentifier FROM EmailMessage WHERE Subject = 'Target Email' LIMIT 1];
        EmailMessageFileCopyAction.Request req = new EmailMessageFileCopyAction.Request();
        req.sourceEmailMessages = new List<EmailMessage>{sourceEmail};
        req.targetEmailMessages = new List<EmailMessage>{targetEmail};
        Test.startTest();
        EmailMessageFileCopyAction.copyFiles(new List<EmailMessageFileCopyAction.Request>{req});
        Test.stopTest();
        List<ContentDocumentLink> links = [
            SELECT Id, ContentDocumentId, LinkedEntityId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :targetEmail.Id
        ];
        System.assertEquals(1, links.size(), 'File should be copied to target EmailMessage');
    }
    @IsTest
    static void testEmptyRequest() {
        Test.startTest();
        EmailMessageFileCopyAction.copyFiles(new List<EmailMessageFileCopyAction.Request>());
        EmailMessageFileCopyAction.copyFiles(null);
        Test.stopTest();
        System.assert(true);
    }
    @IsTest
    static void testEmptyEmailCollections() {
        EmailMessageFileCopyAction.Request req = new EmailMessageFileCopyAction.Request();
        req.sourceEmailMessages = new List<EmailMessage>();
        req.targetEmailMessages = new List<EmailMessage>();
        Test.startTest();
        EmailMessageFileCopyAction.copyFiles(new List<EmailMessageFileCopyAction.Request>{req});
        Test.stopTest();
        System.assert(true);
    }
}