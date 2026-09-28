/**
Handles HTML to PDF renderer communication.
*/
public with sharing class HtmlEmailPdfService {
    
    private static final String NAMED_CREDENTIAL = 'callout:Html_To_Pdf_Renderer';
    
    public static Blob render(String htmlBody) {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(NAMED_CREDENTIAL);
        request.setMethod('POST');
        request.setTimeout(120000);
        request.setHeader('Content-Type', 'application/json');
        
        Map<String,String> payload = new Map<String,String>{'html' => htmlBody};
            
        request.setBody(JSON.serialize(payload) );
        HttpResponse response =
            new Http().send(request);
        if(response.getStatusCode() != 200){
            throw new EmailPdfRenderException('PDF conversion failed');
        }
        return response.getBodyAsBlob();
    }
}