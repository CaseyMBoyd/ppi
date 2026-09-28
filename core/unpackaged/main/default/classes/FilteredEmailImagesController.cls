public with sharing class FilteredEmailImagesController {
    
    /**
* Get filtered embedded images for the current Lead or Opportunity.
*/
    @AuraEnabled(cacheable=true)
    public static List<ContentVersion> getFilteredImages(Id recordId) {
        
        System.debug('### LWC recordId = ' + recordId);
        
        if (recordId == null) {
            System.debug('### recordId is NULL');
            return new List<ContentVersion>();
        }
        
        List<ContentVersion> images = [
            SELECT Id,
            Title,
            PathOnClient,
            ContentSize,
            ContentDocumentId,
            FileExtension,
            CreatedDate,
            Filtered_Email_RecordId__c,
            Is_Filtered_Email_Image__c
            FROM ContentVersion
            WHERE Filtered_Email_RecordId__c = :String.valueOf(recordId)
            AND Is_Filtered_Email_Image__c = true
            AND IsLatest = true
            ORDER BY CreatedDate ASC
        ];
        
        System.debug('### FILTERED IMAGE COUNT = ' + images.size());
        System.debug('### FILTERED IMAGES = ' + images);
        
        return images;
    }
    
    /**
* Add the selected filtered image to the current Lead/Opportunity Files.
*/
    @AuraEnabled
    public static void addToFiles(Id contentDocumentId, Id recordId) {
        
        if (contentDocumentId == null || recordId == null) {
            throw new AuraHandledException('Content Document Id and Record Id are required.');
        }
        
        List<ContentDocumentLink> existingLinks = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :contentDocumentId
            AND LinkedEntityId = :recordId
            LIMIT 1
        ];
        
        if (existingLinks.isEmpty()) {
            ContentDocumentLink fileLink = new ContentDocumentLink();
            fileLink.ContentDocumentId = contentDocumentId;
            fileLink.LinkedEntityId = recordId;
            fileLink.ShareType = 'V';
            fileLink.Visibility = 'AllUsers';
            insert fileLink;
        }
        
        List<ContentVersion> images = [
            SELECT Id,
            Filtered_Email_RecordId__c,
            Is_Filtered_Email_Image__c
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
            AND Filtered_Email_RecordId__c = :String.valueOf(recordId)
            AND Is_Filtered_Email_Image__c = true
            AND IsLatest = true
            LIMIT 1
        ];
        
        if (!images.isEmpty()) {
            ContentVersion image = images[0];
            image.Filtered_Email_RecordId__c = null;
            image.Is_Filtered_Email_Image__c = false;
            update image;
        }
    }
}