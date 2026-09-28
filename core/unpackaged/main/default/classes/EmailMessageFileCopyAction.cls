public without sharing class EmailMessageFileCopyAction {

    public class Request {
        @InvocableVariable(required=true)
        public List<EmailMessage> sourceEmailMessages;

        @InvocableVariable(required=true)
        public List<EmailMessage> targetEmailMessages;
    }
    @InvocableMethod(
        label='Copy Email Message Files'
        description='Copies Files from original Email Messages to newly created Email Messages'
    )
    public static void copyFiles(List<Request> requests) {
        if (requests == null || requests.isEmpty()) {
            return;
        }

        List<EmailMessage> sourceEmails = requests[0].sourceEmailMessages;
        List<EmailMessage> targetEmails = requests[0].targetEmailMessages;

        if (sourceEmails == null || sourceEmails.isEmpty() || targetEmails == null || targetEmails.isEmpty()) {
            return;
        }

        // New Email MessageIdentifier → New Email Id
        Map<String, Id> targetEmailMap =new Map<String, Id>();

        for (EmailMessage email : targetEmails) {
            if (email.Id != null && String.isNotBlank(email.MessageIdentifier)) {
                targetEmailMap.put(email.MessageIdentifier,email.Id);
            }
        }
		Set<Id> sourceEmailIds =new Set<Id>();
        Map<Id, String> sourceIdentifierMap =new Map<Id, String>();
        
        for (EmailMessage email : sourceEmails) {
            if (email.Id != null) {
                sourceEmailIds.add(email.Id);
                sourceIdentifierMap.put( email.Id,email.MessageIdentifier );
            }
        }
        if (sourceEmailIds.isEmpty() || targetEmailMap.isEmpty()) {
            return;
        }
        // Get existing email files 
        List<ContentDocumentLink> existingLinks =[SELECT ContentDocumentId, LinkedEntityId FROM ContentDocumentLink
                              WHERE LinkedEntityId IN :sourceEmailIds ];

        List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();
        for (ContentDocumentLink oldLink : existingLinks) {
            String identifier =sourceIdentifierMap.get(oldLink.LinkedEntityId);
            Id newEmailId =targetEmailMap.get(identifier);
            if (newEmailId != null) {
                newLinks.add(
                    new ContentDocumentLink(
                        ContentDocumentId = oldLink.ContentDocumentId,
                        LinkedEntityId =newEmailId,
                        ShareType = 'V',
                        Visibility = 'AllUsers'));
            }
        }
        // ONE INSERT
        if (!newLinks.isEmpty()) {
            insert newLinks;
        }
    }
}