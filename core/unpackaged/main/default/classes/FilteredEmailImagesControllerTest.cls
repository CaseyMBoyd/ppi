@IsTest
private class FilteredEmailImagesControllerTest {
    
    /**
* Test getFilteredImages() when recordId is null.
*/
    @IsTest
    static void testGetFilteredImages_NullRecordId() {
        
        Test.startTest();
        
        List<ContentVersion> result =FilteredEmailImagesController.getFilteredImages(null);
        
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertEquals(0,result.size(),'Expected empty list when recordId is null.');
    }
    
    
    /**
* Test getFilteredImages() when no matching images exist.
*/
    @IsTest
    static void testGetFilteredImages_NoImages() {
        
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;
        
        Test.startTest();
        
        List<ContentVersion> result = FilteredEmailImagesController.getFilteredImages(testAccount.Id);
        
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertEquals(0,result.size(),'Expected no filtered images.');
    }
    
    
    /**
* Test getFilteredImages() with matching filtered image.
*/
    @IsTest
    static void testGetFilteredImages_WithImages() {
        
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;
        
        ContentVersion image = new ContentVersion(
            Title = 'Image_1',
            PathOnClient = 'image.png',
            VersionData = Blob.valueOf('Test Image Data'),
            Filtered_Email_RecordId__c = String.valueOf(testAccount.Id),
            Is_Filtered_Email_Image__c = true
        );
        
        insert image;
        
        Test.startTest();
        
        List<ContentVersion> result = FilteredEmailImagesController.getFilteredImages(testAccount.Id);
        
        Test.stopTest();
        
        System.assertEquals(1,result.size(),'Expected one filtered image.');
        
        System.assertEquals('Image_1',result[0].Title );
        
        System.assertEquals(true,result[0].Is_Filtered_Email_Image__c);
        
        System.assertEquals( String.valueOf(testAccount.Id), result[0].Filtered_Email_RecordId__c
                           );
    }
    
    
    /**
* Test addToFiles() with null parameters.
*/
    @IsTest
    static void testAddToFiles_NullParameters() {
        
        Test.startTest();
        
        try {
            FilteredEmailImagesController.addToFiles(null, null);
            
            System.assert(false, 'Expected AuraHandledException.');
            
        } catch (AuraHandledException e) {
            
            System.assertNotEquals(
                null,
                e,
                'Expected AuraHandledException to be thrown.'
            );
        }
        
        Test.stopTest();
    }
    
    /**
* Test addToFiles() when the file is not already linked.
*/
    @IsTest
    static void testAddToFiles_NewLink() {
        
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;
        
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'test.txt',
            VersionData = Blob.valueOf('Test File Content')
        );
        insert cv;
        
        ContentVersion insertedVersion = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];
        
        Test.startTest();
        
        FilteredEmailImagesController.addToFiles(insertedVersion.ContentDocumentId,testAccount.Id);
        
        Test.stopTest();
        
        List<ContentDocumentLink> links = [
            SELECT Id,
            ContentDocumentId,
            LinkedEntityId,
            ShareType,
            Visibility
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :insertedVersion.ContentDocumentId
            AND LinkedEntityId = :testAccount.Id
        ];
        
        System.assertEquals(
            1,
            links.size(),
            'Expected one ContentDocumentLink.'
        );
        
        System.assertEquals(
            insertedVersion.ContentDocumentId,
            links[0].ContentDocumentId
        );
        
        System.assertEquals(
            testAccount.Id,
            links[0].LinkedEntityId
        );
        
        System.assertEquals(
            'V',
            links[0].ShareType
        );
        
        System.assertEquals(
            'AllUsers',
            links[0].Visibility
        );
    }
    
    
    /**
* Test addToFiles() when the file is already linked.
* The method should return without creating another link.
*/
    @IsTest
    static void testAddToFiles_ExistingLink() {
        
        Account testAccount = new Account(
            Name = 'Test Account'
        );
        insert testAccount;
        
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'test.txt',
            VersionData = Blob.valueOf('Test File Content')
        );
        insert cv;
        
        ContentVersion insertedVersion = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];
        
        ContentDocumentLink existingLink = new ContentDocumentLink(
            ContentDocumentId = insertedVersion.ContentDocumentId,
            LinkedEntityId = testAccount.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        
        insert existingLink;
        
        Test.startTest();
        
        FilteredEmailImagesController.addToFiles(
            insertedVersion.ContentDocumentId,
            testAccount.Id
        );
        
        Test.stopTest();
        
        Integer linkCount = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :insertedVersion.ContentDocumentId
            AND LinkedEntityId = :testAccount.Id
        ];
        
        System.assertEquals(
            1,
            linkCount,
            'Duplicate ContentDocumentLink should not be created.'
        );
    }
}