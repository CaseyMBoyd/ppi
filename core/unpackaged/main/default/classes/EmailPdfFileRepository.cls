/**
 * Repository for Salesforce PDF file operations.
 * Purpose:Store generated PDF as Salesforce File.
  Document recommends: ContentVersion with FirstPublishLocationId so Salesforce automatically links the file.
 */
public with sharing class EmailPdfFileRepository {
    public static Id insertPdf(Id parentRecordId, String fileName, Blob pdfBody) {
        if(parentRecordId == null){

            throw new AuraHandledException(
                'Parent record is required.'
            );
        }
        ContentVersion version = new ContentVersion();

        version.Title =removePdfExtension(fileName);
        version.PathOnClient = fileName;
        version.VersionData =pdfBody;
        version.FirstPublishLocationId = parentRecordId;

        version.IsMajorVersion = true;
        insert version;
        return version.Id;
    }

    private static String removePdfExtension(String fileName){
        if(
            String.isNotBlank(fileName)
            &&
            fileName.toLowerCase()
            .endsWith('.pdf')
        ){
            return fileName.substring(
                0,
                fileName.length() - 4
            );
        }
        return fileName;
    }
}