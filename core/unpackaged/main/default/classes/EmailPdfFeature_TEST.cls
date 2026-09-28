@IsTest
public class EmailPdfFeature_TEST {
    
    private class PdfSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request){
            System.assertEquals('POST',request.getMethod());
            System.assert(request.getBody().contains('html'));
            
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setHeader('Content-Type','application/pdf');
            response.setBodyAsBlob(Blob.valueOf('Fake PDF Content'));
            return response;
        }
    }
    
    private class PdfFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request){
            HttpResponse response = new HttpResponse();
            response.setStatusCode(500);
            response.setBody('Renderer Error');
            return response;
        }
    }
    
    @IsTest
    static void testCompletePdfGenerationFlow(){
        
        Account acc = new Account(Name='PDF Test Account');
        insert acc;
        
        Messaging.InboundEmail.BinaryAttachment image =
            new Messaging.InboundEmail.BinaryAttachment();
        
        image.fileName = 'image001.png';
        image.mimeTypeSubType = 'image/png';
        image.body = Blob.valueOf('Image Body');
        
        List<Messaging.InboundEmail.BinaryAttachment> images =
            new List<Messaging.InboundEmail.BinaryAttachment>{image};
                
                String html =
                '<html><body>' +
                'Hello Customer' +
                '<img src="cid:image001.png">' +
                '<script>alert("test")</script>' +
                '</body></html>';
        
        Test.setMock(HttpCalloutMock.class,new PdfSuccessMock());
        
        Test.startTest();
        System.enqueueJob(new EmailPdfConversionJob(acc.Id,html,images));
        Test.stopTest();
        
        ContentVersion version = [
            SELECT Id,Title,ContentDocumentId
            FROM ContentVersion
            WHERE Title LIKE 'Customer_Request%'
            LIMIT 1
        ];
        
        System.assertNotEquals(null,version.Id);
        
        EmailPdfPreviewController.PdfPreviewDto dto =
            EmailPdfPreviewController.getLatestPdf(acc.Id);
        
        System.assertNotEquals(null,dto);
        System.assertEquals(version.ContentDocumentId,dto.contentDocumentId);
        System.assert(dto.previewUrl.contains(version.Id));
    }
    
    @IsTest
    static void testPdfWithoutImages(){
        
        Account acc = new Account(Name='No Image Test');
        insert acc;
        
        Test.setMock(HttpCalloutMock.class,new PdfSuccessMock());
        
        Test.startTest();
        System.enqueueJob(
            new EmailPdfConversionJob(
                acc.Id,
                '<html><body>Hello</body></html>',
                null
            )
        );
        Test.stopTest();
        
        List<ContentVersion> files = [
            SELECT Id
            FROM ContentVersion
            WHERE Title LIKE 'Customer_Request%'
        ];
        
        System.assertEquals(1,files.size());
    }
    
    @IsTest
    static void testRendererFailure(){
        
        Test.setMock(HttpCalloutMock.class,new PdfFailureMock());
        
        Boolean isException = false;
        
        Test.startTest();
        
        try{
            HtmlEmailPdfService.render('<html>Hello</html>');
        }
        catch(EmailPdfRenderException ex){
            isException = true;
        }
        
        Test.stopTest();
        
        System.assertEquals(true,isException);
    }
    
    @IsTest
    static void testFileRepositoryException(){
        
        Boolean isException = false;
        
        try{
            EmailPdfFileRepository.insertPdf(
                null,
                'Customer_Request.pdf',
                Blob.valueOf('PDF')
            );
        }
        catch(AuraHandledException ex){
            isException = true;
        }
        
        System.assertEquals(true,isException);
    }
    
    @IsTest
    static void testPreviewWithoutFile(){
        
        Account acc = new Account(Name='Empty Preview');
        insert acc;
        
        EmailPdfPreviewController.PdfPreviewDto dto =
            EmailPdfPreviewController.getLatestPdf(acc.Id);
        
        System.assertNotEquals(null,dto);
        System.assertEquals('NO_FILE',dto.status);
        System.assertEquals(null,dto.contentDocumentId);
    }
}