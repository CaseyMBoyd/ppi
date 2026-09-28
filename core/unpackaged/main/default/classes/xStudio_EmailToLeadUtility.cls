public without sharing class xStudio_EmailToLeadUtility {
    public static List<EmailMessage> getExistingEmailMessages(
        List<String> references
    ) {
        return [
            SELECT Id, RelatedToId
            FROM EmailMessage
            WHERE MessageIdentifier IN :references
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
    }
    
    public static List<EmailMessage> linkToExistingEmailMessages(
        List<EmailMessage> existingEmailMessages,
        Messaging.InboundEmail inboundEmail
    ) {
        List<EmailMessage> linkedEmailMessages = new List<EmailMessage>();
        List<ContentVersion> filteredImages = new List<ContentVersion>();
        Integer filteredImageNumber = 0;
        
        Set<String> relatedRecordIds = new Set<string>();
        // Collect Lead/Opportunity Ids from existing EmailMessages.
        for (EmailMessage existingEmail : existingEmailMessages) {
            if (existingEmail.RelatedToId != null) {
                relatedRecordIds.add(existingEmail.RelatedToId);
            }
        }
        try {
            Map<Id, Set<String>> existingImageHashesByRecord = new Map<Id, Set<String>>();
            if (!relatedRecordIds.isEmpty()) {
                for (ContentVersion existingImage : [SELECT Id,Filtered_Email_RecordId__c,Filtered_Email_Image_Hash__c FROM ContentVersion WHERE Filtered_Email_RecordId__c IN :relatedRecordIds AND Is_Filtered_Email_Image__c = true AND IsLatest = true AND Filtered_Email_Image_Hash__c != null]) {
                    Id relatedRecordId = Id.valueOf(existingImage.Filtered_Email_RecordId__c);
                    if (!existingImageHashesByRecord.containsKey(relatedRecordId)) {
                        existingImageHashesByRecord.put(relatedRecordId, new Set<String>() );
                    }
                    existingImageHashesByRecord.get(relatedRecordId).add(existingImage.Filtered_Email_Image_Hash__c);
                }
            }
            for (EmailMessage existingEmail : existingEmailMessages) {
                Logger.info('Existing EmailMessage Found').setRecord(existingEmail.Id);
                Logger.info('Email From Name: ' + inboundEmail.fromName);
                Logger.info('Email From Address: ' + inboundEmail.fromAddress);
                EmailMessage linkedEmailMessage = new EmailMessage();
                if (inboundEmail.toAddresses != null) {
                    linkedEmailMessage.ToAddress =
                        String.join(inboundEmail.toAddresses, ',');
                }
                if (
                    inboundEmail.ccAddresses != null
                    && inboundEmail.ccAddresses.size() > 0
                ) {
                    linkedEmailMessage.CcAddress =
                        String.join(inboundEmail.ccAddresses, ',');
                }
                if (
                    inboundEmail.htmlBody != null
                    && inboundEmail.htmlBody.length() > 131071
                ) {
                    inboundEmail.htmlBody = inboundEmail.htmlBody.substring(0, 131071);
                }
                if (
                    inboundEmail.plainTextBody != null
                    && inboundEmail.plainTextBody.length() > 131071
                ) {
                    inboundEmail.plainTextBody =
                        inboundEmail.plainTextBody.substring(0, 131071);
                }
                String subject =
                    inboundEmail.subject != null
                    ? inboundEmail.subject
                    : 'No Subject Found';
                linkedEmailMessage.FromAddress = inboundEmail.FromAddress;
                linkedEmailMessage.FromName = inboundEmail.FromName;
                linkedEmailMessage.Subject = subject;
                linkedEmailMessage.status = '1';
                linkedEmailMessage.HtmlBody = inboundEmail.htmlBody;
                linkedEmailMessage.Incoming = true;
                linkedEmailMessage.TextBody = inboundEmail.plainTextBody;
                linkedEmailMessage.RelatedToId = existingEmail.RelatedToId;
                linkedEmailMessage.MessageIdentifier = inboundEmail.messageId;
                linkedEmailMessage.ClientThreadIdentifier =
                    getClientThreadIdentifier(inboundEmail.headers);
                linkedEmailMessage.IsClientManaged = true;
                insert linkedEmailMessage;
                linkedEmailMessages.add(linkedEmailMessage);
                
                if (existingEmail.RelatedToId != null) {
                    ContentVersion cvOppEmail = new ContentVersion();
                    if (inboundEmail.htmlBody != null && inboundEmail.htmlBody != '')
                        cvOppEmail.VersionData = Blob.valueOf(inboundEmail.htmlBody);
                    else {
                        cvOppEmail.VersionData = Blob.valueOf(inboundEmail.plainTextBody);
                    }
                    
                    if (
                        cvOppEmail.VersionData == null
                        || cvOppEmail.VersionData.toString() == ''
                    ) {
                        cvOppEmail.VersionData = Blob.valueOf('Email Body Missing');
                    }
                    
                    cvOppEmail.Title = subject;
                    cvOppEmail.PathOnClient = subject + '.html';
                    //Jignasha Patel commented this code
                    /*insert cvOppEmail;

                    cvOppEmail = [
                    SELECT ContentDocumentId
                    FROM ContentVersion
                    WHERE id = :cvOppEmail.id
                    LIMIT 1
                    ];
                    ContentDocumentLink cdlOppEmail = new ContentDocumentLink();
                    cdlOppEmail.LinkedEntityId = existingEmail.RelatedToId;
                    cdlOppEmail.ContentDocumentId = cvOppEmail.ContentDocumentId;
                    cdlOppEmail.ShareType = 'V';
                    insert cdlOppEmail;*/
                    // Generate PDF version of inbound email
                    if (String.isNotBlank(inboundEmail.htmlBody)) {
                        String emailBodyForPdf = 
                            String.isNotBlank(inboundEmail.htmlBody)
                            ? inboundEmail.htmlBody
                            : '<html><body>' + inboundEmail.plainTextBody + '</body></html>';
                        // Temporary debug
                        System.debug('===== Email Headers =====');
                        
                        for(Messaging.InboundEmail.Header header : inboundEmail.headers){
                            System.debug(header.name + ' = ' + header.value);
                        }
                        System.enqueueJob(new EmailPdfConversionJob(existingEmail.RelatedToId,emailBodyForPdf,inboundEmail.binaryAttachments,inboundEmail.subject,
                                                                    inboundEmail.fromAddress,inboundEmail.toAddresses,inboundEmail.ccAddresses,System.now()));
                    }  
                }
                // if (
                //   existingEmail.RelatedToId != null
                //   && existingEmail.RelatedToId.getSObjectType()
                //     === Opportunity.getSObjectType()
                // ) {
                //   Opportunity updateOpp = new Opportunity();
                //   updateOpp.Id = existingEmail.RelatedToId;
                //   updateOpp.Customer_Request_Subject__c = inboundEmail.subject;
                //   if(inboundEmail.htmlBody != null && inboundEmail.htmlBody.length() > 131071) {
                //     updateOpp.Email_Content__c = inboundEmail.htmlBody.substring(0, 131071);
                //   } else {
                //     updateOpp.Email_Content__c = inboundEmail.htmlBody;
                //   }
                //   update updateOpp;
                // }
                // Custom Notification on Reply Code
                // if (
                //   existingEmail.RelatedToId != null
                //   && existingEmail.RelatedToId.getSObjectType()
                //     === Opportunity.getSObjectType()
                // ) {
                //   Opportunity linkedOpp = [
                //     SELECT Id, OwnerId, Name
                //     FROM Opportunity
                //     WHERE Id = :existingEmail.RelatedToId
                //     WITH SYSTEM_MODE
                //     LIMIT 1
                //   ];
                //   CustomNotificationType notificationType = [
                //     SELECT Id, DeveloperName
                //     FROM CustomNotificationType
                //     WHERE DeveloperName = 'Opportunity_Email_Notification'
                //   ];
                //   Messaging.CustomNotification notification =
                //     new Messaging.CustomNotification();
                //   notification.setTitle('Email Reply Notification');
                //   notification.setBody(
                //     'Email reply received for opportunity: ' + linkedOpp.Name
                //   );
                //   notification.setNotificationTypeId(notificationType.Id);
                //   notification.setTargetId(linkedOpp.Id);
                //   Set<String> recipientsIds = new Set<String>();
                //   recipientsIds.add(linkedOpp.OwnerId);
                //   notification.send(recipientsIds);
                // }
                
                EmailMessageRelation emr = new EmailMessageRelation();
                emr.EmailMessageId = linkedEmailMessage.id;
                emr.RelationAddress = inboundEmail.FromAddress;
                emr.RelationType = 'FromAddress';
                insert emr;
                
                if (inboundEmail.binaryAttachments != null) {
                    for (Messaging.InboundEmail.binaryAttachment binAttach : inboundEmail.binaryAttachments) {
                        System.debug('===== ATTACHMENT DETAILS =====');
                        System.debug('File Name: ' + binAttach.fileName);
                        System.debug('MIME Type: ' + binAttach.mimeTypeSubType);
                        System.debug('Size: ' + (binAttach.body != null ? binAttach.body.size() : 0));
                        System.debug('Headers: ' + binAttach.headers);
                        
                        if (binAttach.headers != null) {
                            for (Messaging.InboundEmail.Header header : binAttach.headers) {
                                System.debug('HEADER NAME: ' + header.name);
                                System.debug('HEADER VALUE: ' + header.value);
                            }
                        }
                        Logger.info(
                            'Binary Attachment: '
                            + binAttach.fileName
                            + ' (Size: '
                            + binAttach.body.size()
                            + ')'
                        );
                        Logger.info(
                            'Binary Attachment: '
                            + binAttach.fileName
                            + ' (MIME: '
                            + binAttach.mimeTypeSubType
                            + ')'
                        );
                        Logger.info(
                            'Binary Attachment: '
                            + binAttach.fileName
                            + ' (Headers: '
                            + binAttach.headers
                            + ')'
                        );
                        system.debug('isEmbeddedImage(binAttach)___ ' + isEmbeddedImage(binAttach));
                        if (isEmbeddedImage(binAttach)) {
                            
                            if (binAttach.body == null || binAttach.body.size() == 0) {
                                continue;
                            }
                            
                            Id relatedRecordId = existingEmail.RelatedToId;
                            
                            String imageHash = EncodingUtil.convertToHex(
                                Crypto.generateDigest('SHA-256', binAttach.body)
                            );
                            
                            Set<String> existingHashes =
                                existingImageHashesByRecord.get(relatedRecordId);
                            
                            if (existingHashes == null) {
                                existingHashes = new Set<String>();
                                
                                existingImageHashesByRecord.put(
                                    relatedRecordId,
                                    existingHashes
                                );
                            }
                            
                            // Skip image if the same image already exists
                            // for this Lead/Opportunity.
                            if (existingHashes.contains(imageHash)) {
                                continue;
                            }
                            
                            filteredImageNumber++;
                            
                            ContentVersion filteredImage = new ContentVersion();
                            String imageTimestamp = Datetime.now().format('yyyy-MM-dd_HH:mm:ss');
                            filteredImage.VersionData = binAttach.body;
                            filteredImage.Title = 'Image_' + filteredImageNumber + '_' + imageTimestamp;
                            filteredImage.PathOnClient = binAttach.fileName;
                            filteredImage.Filtered_Email_RecordId__c =
                                String.valueOf(relatedRecordId);
                            filteredImage.Is_Filtered_Email_Image__c = true;
                            filteredImage.Filtered_Email_Image_Hash__c = imageHash;
                            
                            filteredImages.add(filteredImage);
                            
                            // Prevent the same image from being added twice
                            // during this same execution.
                            existingHashes.add(imageHash);
                            
                            continue;
                        }
                        ContentVersion cv = new ContentVersion();
                        if (binAttach.body.size() > 0) {
                            cv.VersionData = binAttach.body;
                        } else {
                            cv.VersionData = Blob.valueOf('Attachment Body Missing');
                        }
                        cv.Title = binAttach.fileName;
                        cv.PathOnClient = binAttach.fileName;
                        insert cv;
                        
                        cv = [
                            SELECT ContentDocumentId
                            FROM ContentVersion
                            WHERE id = :cv.id
                            LIMIT 1
                        ];
                        
                        ContentDocumentLink cdl = new ContentDocumentLink();
                        cdl.LinkedEntityId = linkedEmailMessage.id;
                        cdl.ContentDocumentId = cv.ContentDocumentId;
                        cdl.ShareType = 'V';
                        insert cdl;
                        
                        if (linkedEmailMessage.RelatedToId != null) {
                            ContentDocumentLink cdlOpp = new ContentDocumentLink();
                            cdlOpp.LinkedEntityId = linkedEmailMessage.RelatedToId;
                            cdlOpp.ContentDocumentId = cv.ContentDocumentId;
                            cdlOpp.ShareType = 'V';
                            insert cdlOpp;
                        }
                    }
                }
            }
            system.debug('filteredImages@@ ' + filteredImages);
            if (!filteredImages.isEmpty()) {
                insert filteredImages;
                System.debug('SUCCESS - filteredImages inserted: ' + filteredImages);
            }
        } catch (Exception ex) {
            Logger.error('Failed to link to existing emails: ', ex);
        } finally {
            Logger.saveLog();
        }
        return linkedEmailMessages;
    }
    
    public static Lead createLead(
        Messaging.InboundEmail inboundEmail,
        String leadQueue
    ) {
        Lead newLead = new Lead();
        Logger.info('No existing EmailMessage found. Creating Lead.');
        Logger.info('Email From Name: ' + inboundEmail.fromName);
        Logger.info('Email From Address: ' + inboundEmail.fromAddress);
        try {
            List<Contact> existingContacts = [
                SELECT Id, AccountId
                FROM Contact
                WHERE Email = :inboundEmail.FromAddress
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            
            List<String> nameTokens = inboundEmail.FromName.split(' ');
            
            Id queueId =
                [
                    SELECT Queue.Id
                    FROM QueueSObject
                    WHERE Queue.Name = 'New Leads'
                    WITH SYSTEM_MODE
                    LIMIT 1
                ]
                .Queue
                .Id;
            String emailContentString = '';
            if (inboundEmail.toAddresses != null) {
                emailContentString =
                    emailContentString
                    + 'To: '
                    + String.join(inboundEmail.toAddresses, ', ')
                    + '<br/>';
            }
            if (
                inboundEmail.ccAddresses != null && inboundEmail.ccAddresses.size() > 0
            ) {
                emailContentString =
                    emailContentString
                    + 'CC Addresses: '
                    + String.join(inboundEmail.ccAddresses, ';')
                    + '<br/>';
            }
            if (
                inboundEmail.htmlBody != null
                && inboundEmail.htmlBody != ''
                && !inboundEmail.htmlBody.contains('data:text/html')
            )
                emailContentString = emailContentString + inboundEmail.htmlBody;
            else {
                emailContentString = emailContentString + inboundEmail.plainTextBody;
                emailContentString =
                    emailContentString.replaceAll('\r\n|\n|\r', '<br/>');
            }
            
            if (emailContentString.length() > 131071) {
                emailContentString = emailContentString.substring(0, 131071);
            }
            
            String firstName = nameTokens.remove(0);
            String lastName =
                nameTokens.size() > 0
                ? nameTokens.remove(nameTokens.size() - 1)
                : firstName;
            
            if (firstName.length() > 40) {
                firstName = firstName.substring(0, 40);
            }
            
            if (lastName.length() > 80) {
                lastName = lastName.substring(0, 80);
            }
            
            String subject =
                inboundEmail.subject != null
                ? inboundEmail.subject
                : 'No Subject Found';
            Logger.info('Lead queue: ' + leadQueue);
            Logger.info('Email subject: ' + subject);
            if (existingContacts.size() == 0 || inboundEmail.fromAddress == 'system@sent-via.netsuite.com') {
                newLead =
                    new Lead(
                        Company = inboundEmail.fromName,
                        FirstName = firstName,
                        LastName = lastName,
                        Email = inboundEmail.fromAddress,
                        LeadSource = 'Email',
                        Lead_Queue__c = leadQueue,
                        Email_Content__c = emailContentString,
                        Customer_Request_Subject__c = subject,
                        OwnerId = queueId
                    );
            } else {
                newLead =
                    new Lead(
                        Company = inboundEmail.fromName,
                        FirstName = firstName,
                        LastName = lastName,
                        Email = inboundEmail.fromAddress,
                        LeadSource = 'Email',
                        Contact__c = existingContacts[0].Id,
                        Account__c = existingContacts[0].AccountId,
                        Lead_Queue__c = leadQueue,
                        Email_Content__c = emailContentString,
                        Customer_Request_Subject__c = subject,
                        OwnerId = queueId
                    );
            }
            Logger.info('New Lead Record', newLead);
            insert newLead;
            
            ContentVersion cvLead = new ContentVersion();
            if (inboundEmail.htmlBody != null && inboundEmail.htmlBody != '')
                cvLead.VersionData = Blob.valueOf(inboundEmail.htmlBody);
            else {
                cvLead.VersionData = Blob.valueOf(inboundEmail.plainTextBody);
            }
            
            if (cvLead.VersionData == null || cvLead.VersionData.toString() == '') {
                cvLead.VersionData = Blob.valueOf('Email Body Missing');
            }
            
            cvLead.Title = subject;
            cvLead.PathOnClient = subject + '.html';
            //Jignasha Patel commented this code
            /*insert cvLead; 
            cvLead = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE id = :cvLead.id
            LIMIT 1
            ];
            
            ContentDocumentLink cdlLead = new ContentDocumentLink();
            cdlLead.LinkedEntityId = newLead.id;
            cdlLead.ContentDocumentId = cvLead.ContentDocumentId;
            cdlLead.ShareType = 'V';
            insert cdlLead;*/
            // Generate PDF version of inbound email
            if (String.isNotBlank(inboundEmail.htmlBody)) {
                String emailBodyForPdf =
                    String.isNotBlank(inboundEmail.htmlBody)
                    ? inboundEmail.htmlBody
                    : '<html><body>' + inboundEmail.plainTextBody + '</body></html>';
                
                System.enqueueJob(new EmailPdfConversionJob(newLead.Id,emailBodyForPdf,inboundEmail.binaryAttachments,inboundEmail.subject,
                                                            inboundEmail.fromAddress,inboundEmail.toAddresses,inboundEmail.ccAddresses,
                                                            System.now()));
            }
            EmailMessage leadEmailMessage = new EmailMessage();
            if (inboundEmail.toAddresses != null) {
                leadEmailMessage.ToAddress = String.join(inboundEmail.toAddresses, ',');
            }
            if (
                inboundEmail.ccAddresses != null && inboundEmail.ccAddresses.size() > 0
            ) {
                leadEmailMessage.CcAddress = String.join(inboundEmail.ccAddresses, ',');
            }
            if (
                inboundEmail.htmlBody != null && inboundEmail.htmlBody.length() > 131071
            ) {
                inboundEmail.htmlBody = inboundEmail.htmlBody.substring(0, 131071);
            }
            if (
                inboundEmail.plainTextBody != null
                && inboundEmail.plainTextBody.length() > 131071
            ) {
                inboundEmail.plainTextBody =
                    inboundEmail.plainTextBody.substring(0, 131071);
            }
            leadEmailMessage.FromAddress = inboundEmail.FromAddress;
            leadEmailMessage.FromName = inboundEmail.FromName;
            leadEmailMessage.Subject = subject;
            leadEmailMessage.status = '1';
            leadEmailMessage.HtmlBody = inboundEmail.htmlBody;
            leadEmailMessage.Incoming = true;
            leadEmailMessage.TextBody = inboundEmail.plainTextBody;
            leadEmailMessage.MessageIdentifier = inboundEmail.messageId;
            leadEmailMessage.ClientThreadIdentifier =
                getClientThreadIdentifier(inboundEmail.headers);
            leadEmailMessage.IsClientManaged = true;
            insert leadEmailMessage;
            
            EmailMessageRelation emr = new EmailMessageRelation();
            emr.EmailMessageId = leadEmailMessage.Id;
            emr.RelationId = newLead.Id;
            emr.RelationType = 'FromAddress';
            insert emr;
            System.debug('===== EMAIL HTML BODY =====');
            System.debug(inboundEmail.htmlBody);
            List<ContentVersion> filteredImages = new List<ContentVersion>();
            Integer filteredImageNumber = 0;
            Set<String> emailImageHashes = new Set<String>();
            if (inboundEmail.binaryAttachments != null) {
                for (Messaging.InboundEmail.binaryAttachment binAttach : inboundEmail.binaryAttachments) {
                    Logger.info(
                        'Binary Attachment: '
                        + binAttach.fileName
                        + ' (Size: '
                        + binAttach.body.size()
                        + ')'
                    );
                    Logger.info(
                        'Binary Attachment: '
                        + binAttach.fileName
                        + ' (MIME: '
                        + binAttach.mimeTypeSubType
                        + ')'
                    );
                    Logger.info(
                        'Binary Attachment: '
                        + binAttach.fileName
                        + ' (Headers: '
                        + binAttach.headers
                        + ')'
                    );
                    if (isEmbeddedImage(binAttach)) {
                        
                        if (binAttach.body == null || binAttach.body.size() == 0) {
                            continue;
                        }
                        
                        String imageHash = EncodingUtil.convertToHex(
                            Crypto.generateDigest('SHA-256', binAttach.body)
                        );
                        
                        // Prevent the same image from being created twice
                        // in the same email.
                        if (emailImageHashes.contains(imageHash)) {
                            continue;
                        }
                        
                        emailImageHashes.add(imageHash);
                        
                        filteredImageNumber++;
                        
                        ContentVersion filteredImage = new ContentVersion();
                        String imageTimestamp = Datetime.now().format('yyyy-MM-dd_HH:mm:ss');
                        filteredImage.VersionData = binAttach.body;
                        filteredImage.Title = 'Image_' + filteredImageNumber + '_' + imageTimestamp;
                        filteredImage.PathOnClient = binAttach.fileName;
                        filteredImage.Filtered_Email_RecordId__c =
                            String.valueOf(newLead.Id);
                        filteredImage.Is_Filtered_Email_Image__c = true;
                        filteredImage.Filtered_Email_Image_Hash__c = imageHash;
                        
                        filteredImages.add(filteredImage);
                        
                        continue;
                    }
                    ContentVersion cv = new ContentVersion();
                    if (binAttach.body.size() > 0) {
                        cv.VersionData = binAttach.body;
                    } else {
                        cv.VersionData = Blob.valueOf('Attachment Body Missing');
                    }
                    cv.Title = binAttach.fileName;
                    cv.PathOnClient = binAttach.fileName;
                    insert cv;
                    
                    cv = [
                        SELECT ContentDocumentId
                        FROM ContentVersion
                        WHERE id = :cv.id
                        LIMIT 1
                    ];
                    
                    ContentDocumentLink cdl = new ContentDocumentLink();
                    cdl.LinkedEntityId = newLead.id;
                    cdl.ContentDocumentId = cv.ContentDocumentId;
                    cdl.ShareType = 'V';
                    insert cdl;
                    
                    ContentDocumentLink emailCdl = new ContentDocumentLink();
                    emailCdl.LinkedEntityId = leadEmailMessage.Id;
                    emailCdl.ContentDocumentId = cv.ContentDocumentId;
                    emailCdl.ShareType = 'V';
                    insert emailCdl;
                }
                if (!filteredImages.isEmpty()) {
                    insert filteredImages;
                }
            }
        } catch (Exception ex) {
            Logger.error('Failed to create a new Lead from email: ', ex);
        } finally {
            Logger.saveLog();
        }
        return newLead;
    }
    
    private static String getClientThreadIdentifier(
        List<Messaging.InboundEmail.Header> headers
    ) {
        if (headers == null || headers.size() == 0)
            return null;
        try {
            for (Messaging.InboundEmail.Header header : headers) {
                if (header.name.equalsIgnoreCase('thread-index')) {
                    Blob threadIndex = EncodingUtil.base64Decode(header.value.trim());
                    return EncodingUtil.convertToHex(threadIndex)
                        .substring(0, 44)
                        .toUpperCase();
                }
            }
        } catch (Exception e) {
            return null;
        }
        return null;
    }
    private static Boolean isEmbeddedImage(Messaging.InboundEmail.BinaryAttachment binAttach) {
        if (binAttach == null || String.isBlank(binAttach.mimeTypeSubType) || binAttach.headers == null) {
            return false;
        }
        String mimeType = binAttach.mimeTypeSubType.toLowerCase();
        
        Boolean isImage =
            mimeType.contains('jpg') ||
            mimeType.contains('jpeg') ||
            mimeType.contains('png') ||
            mimeType.contains('gif');
        
        if (!isImage) {
            return false;
        }
        
        Boolean isInline = false;
        Boolean hasContentId = false;
        
        for (Messaging.InboundEmail.Header header : binAttach.headers) {
            if (header == null || String.isBlank(header.name)) {
                continue;
            }
            
            if (header.name.toLowerCase() == 'content-disposition' && !String.isBlank(header.value) &&
                header.value.toLowerCase().contains('inline')) {
                    isInline = true;
                }
            
            if (header.name.toLowerCase() == 'content-id' && !String.isBlank(header.value)) {
                hasContentId = true;
            }
        }
        
        return isInline && hasContentId;
    }
}