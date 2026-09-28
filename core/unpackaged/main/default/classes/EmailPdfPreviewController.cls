/**
* Provides generated PDF details to LWC.
*/
public with sharing class EmailPdfPreviewController {
    
    public class PdfPreviewDto {
        @AuraEnabled
        public Id contentDocumentId;
        @AuraEnabled
        public Id contentVersionId;
        @AuraEnabled
        public String title;
        @AuraEnabled
        public String previewUrl;
        @AuraEnabled
        public String status;
    }
    
    @AuraEnabled
    public static PdfPreviewDto getLatestPdf(Id recordId){
        
        PdfPreviewDto dto=new PdfPreviewDto();
        
        List<ContentDocumentLink> links=[
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId=:recordId
        ];
        
        if(!links.isEmpty()){
            
            Set<Id> documentIds=new Set<Id>();
            
            for(ContentDocumentLink link:links){
                documentIds.add(link.ContentDocumentId);
            }
            
            List<ContentVersion> versions=[
                SELECT Id,Title,ContentDocumentId
                FROM ContentVersion
                WHERE ContentDocumentId IN:documentIds
                AND IsLatest=true
                AND Title LIKE 'Customer_Request%'
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            
            if(!versions.isEmpty()){
                ContentVersion version=versions[0];
                
                dto.contentDocumentId=version.ContentDocumentId;
                dto.contentVersionId=version.Id;
                dto.title=version.Title;
                
                dto.previewUrl=
                    '/sfc/servlet.shepherd/version/renditionDownload'
                    +
                    '?rendition=THUMB720BY480'
                    +
                    '&versionId='
                    +
                    version.Id;
                
                dto.status='COMPLETED';
                return dto;
            }
        }
        List<EmailMessage> emails=[
            SELECT Id,CreatedDate
            FROM EmailMessage
            WHERE Incoming=true
            AND RelatedToId=:recordId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if(emails.isEmpty()){
            emails=[
                SELECT Id,CreatedDate
                FROM EmailMessage
                WHERE Incoming=true
                AND ParentId=:recordId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
        }
        if(!emails.isEmpty() && emails[0].CreatedDate.addMinutes(5)>System.now()){
               dto.status='PROCESSING';
           }else{
               dto.status='NO_FILE';
           }
        
        return dto;
    }
}