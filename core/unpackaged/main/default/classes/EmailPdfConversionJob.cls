/**
* Converts inbound email HTML into PDF asynchronously.
*/
public with sharing class EmailPdfConversionJob implements Queueable, Database.AllowsCallouts {
    
    private Id parentRecordId;
    private String htmlBody;
    private String subject;
    private String fromAddress;
    private List<String> toAddresses;
    private List<String> ccAddresses;
    private Datetime sentDate;
    private List<Messaging.InboundEmail.BinaryAttachment> inlineImages;
    
    public EmailPdfConversionJob(
        Id parentRecordId,
        String htmlBody,
        List<Messaging.InboundEmail.BinaryAttachment> inlineImages,
        String subject,
        String fromAddress,
        List<String> toAddresses,
        List<String> ccAddresses,
        Datetime sentDate
    ){
        this.parentRecordId = parentRecordId;
        this.htmlBody = htmlBody;
        this.inlineImages = inlineImages;
        this.subject = subject;
        this.fromAddress = fromAddress;
        this.toAddresses = toAddresses;
        this.ccAddresses = ccAddresses;
        this.sentDate = sentDate;
    }
    
    public void execute(QueueableContext context){
        String htmlWithImages = replaceInlineImages(htmlBody);
        htmlWithImages =  buildEmailHeader() + htmlWithImages;
        
        String safeHtml = HtmlEmailSanitizer.sanitizeAndWrap(htmlWithImages);
        
        Blob pdfBlob = HtmlEmailPdfService.render(safeHtml);
        
        EmailPdfFileRepository.insertPdf(
            parentRecordId,
            'Customer_Request_' + Datetime.now().format('yyyyMMdd_HHmmss') + '.pdf',
            pdfBlob
        );
    }
    
    private String replaceInlineImages(String html) {
        
        if (String.isBlank(html) || inlineImages == null || inlineImages.isEmpty()) {
            return html;
        }
        
        for (Messaging.InboundEmail.BinaryAttachment img : inlineImages) {
            
            if (img == null || img.body == null || img.headers == null) {
                continue;
            }
            
            String contentId;
            
            // Get Content-ID from the attachment headers.
            for (Messaging.InboundEmail.Header header : img.headers) {
                
                if (
                    header != null &&
                    String.isNotBlank(header.name) &&
                    header.name.equalsIgnoreCase('Content-ID') &&
                    String.isNotBlank(header.value)
                ) {
                    contentId = header.value.trim();
                    break;
                }
            }
            
            if (String.isBlank(contentId)) {
                continue;
            }
            
            // Content-ID can be returned with < >.
            contentId = contentId.replace('<', '').replace('>', '').trim();
            
            String cidValue = 'cid:' + contentId;
            
            // Find this specific image reference in the HTML.
            Integer cidStart = html.indexOf(cidValue);
            
            if (cidStart == -1) {
                continue;
            }
            
            String base64Value = EncodingUtil.base64Encode(img.body);
            
            String imageSource =
                'data:' +
                img.mimeTypeSubType +
                ';base64,' +
                base64Value;
            
            html = html.replace(cidValue, imageSource);
        }
        
        return html;
    }
    
    private String buildEmailHeader(){
        
        return
            '<table style="width:100%;border-collapse:collapse;margin-bottom:20px;">'+
            
            '<tr><td><b>Subject</b></td><td>'+(subject==null?'':subject)+'</td></tr>'+
            
            '<tr><td><b>From</b></td><td>'+(fromAddress==null?'':fromAddress)+'</td></tr>'+
            
            '<tr><td><b>To</b></td><td>'+(toAddresses==null?'':String.join(toAddresses,', '))+'</td></tr>'+
            
            '<tr><td><b>CC</b></td><td>'+(ccAddresses==null?'':String.join(ccAddresses,', '))+'</td></tr>'+
            
            '<tr><td><b>Sent</b></td><td>'+(sentDate == null ? '' : sentDate.format('dd-MMM-yyyy hh:mm a'))+'</td></tr>'+
            
            '</table><hr/>';
    }
}