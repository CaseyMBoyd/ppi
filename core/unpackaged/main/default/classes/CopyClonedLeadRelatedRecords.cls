public with sharing class CopyClonedLeadRelatedRecords {
    @InvocableMethod(label='Copy Cloned Lead Files and Activities' description='Copies files, tasks, and events from the source Lead to cloned Leads.')
    public static void copyRelatedRecords(List<Lead> clonedLeads) {
        Map<Id, Id> sourceLeadIdByClonedLeadId = getSourceLeadIdByClonedLeadId(clonedLeads);
        if (sourceLeadIdByClonedLeadId.isEmpty()) {
            return;
        }
        
        copyFiles(sourceLeadIdByClonedLeadId);
        copyEmailMessages(sourceLeadIdByClonedLeadId);
        copyTasks(sourceLeadIdByClonedLeadId);
        copyEvents(sourceLeadIdByClonedLeadId);
    }
    
    private static Map<Id, Id> getSourceLeadIdByClonedLeadId(List<Lead> clonedLeads) {
        Map<Id, Id> sourceLeadIdByClonedLeadId = new Map<Id, Id>();
        
        for (Lead clonedLead : clonedLeads) {
            if (clonedLead.Id == null || String.isBlank(clonedLead.Cloned_From_Lead_Name__c)) {
                continue;
            }
            
            try {
                sourceLeadIdByClonedLeadId.put(
                    clonedLead.Id,
                    (Id) clonedLead.Cloned_From_Lead_Name__c
                );
            } catch (StringException e) {
                continue;
            }
        }
        
        return sourceLeadIdByClonedLeadId;
    }
    
    private static void copyFiles(Map<Id, Id> sourceLeadIdByClonedLeadId) {
        Map<Id, Set<Id>> existingDocumentIdsByLeadId = new Map<Id, Set<Id>>();
        for (ContentDocumentLink existingLink : [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :sourceLeadIdByClonedLeadId.keySet()
            WITH USER_MODE
        ]) {
            if (!existingDocumentIdsByLeadId.containsKey(existingLink.LinkedEntityId)) {
                existingDocumentIdsByLeadId.put(existingLink.LinkedEntityId, new Set<Id>());
            }
            existingDocumentIdsByLeadId.get(existingLink.LinkedEntityId).add(existingLink.ContentDocumentId);
        }
        
        List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
        for (ContentDocumentLink sourceLink : [
            SELECT ContentDocumentId, LinkedEntityId, ShareType, Visibility
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :sourceLeadIdByClonedLeadId.values()
            WITH USER_MODE
        ]) {
            for (Id clonedLeadId : sourceLeadIdByClonedLeadId.keySet()) {
                if (sourceLeadIdByClonedLeadId.get(clonedLeadId) != sourceLink.LinkedEntityId) {
                    continue;
                }
                
                Set<Id> existingDocumentIds = existingDocumentIdsByLeadId.get(clonedLeadId);
                if (existingDocumentIds != null && existingDocumentIds.contains(sourceLink.ContentDocumentId)) {
                    continue;
                }
                
                linksToInsert.add(new ContentDocumentLink(
                    ContentDocumentId = sourceLink.ContentDocumentId,
                    LinkedEntityId = clonedLeadId,
                    ShareType = sourceLink.ShareType,
                    Visibility = sourceLink.Visibility
                ));
            }
        }
        
        if (!linksToInsert.isEmpty()) {
            insert as user linksToInsert;
        }
    }
    
    private static void copyTasks(Map<Id, Id> sourceLeadIdByClonedLeadId) {
        List<Task> tasksToInsert = new List<Task>();
        
        for (Task sourceTask : [
            SELECT
            ActivityDate,
            CallDisposition,
            CallDurationInSeconds,
            CallObject,
            CallType,
            Description,
            IsReminderSet,
            OwnerId,
            Priority,
            ReminderDateTime,
            Status,
            Subject,
            Type,
            WhatId,
            WhoId
            FROM Task
            WHERE WhoId IN :sourceLeadIdByClonedLeadId.values() AND (TaskSubtype != 'Email')
            WITH USER_MODE
        ]) {
            for (Id clonedLeadId : sourceLeadIdByClonedLeadId.keySet()) {
                if (sourceLeadIdByClonedLeadId.get(clonedLeadId) != sourceTask.WhoId) {
                    continue;
                }
                
                tasksToInsert.add(new Task(
                    ActivityDate = sourceTask.ActivityDate,
                    CallDisposition = sourceTask.CallDisposition,
                    CallDurationInSeconds = sourceTask.CallDurationInSeconds,
                    CallObject = sourceTask.CallObject,
                    CallType = sourceTask.CallType,
                    Description = sourceTask.Description,
                    IsReminderSet = sourceTask.IsReminderSet,
                    OwnerId = sourceTask.OwnerId,
                    Priority = sourceTask.Priority,
                    ReminderDateTime = sourceTask.ReminderDateTime,
                    Status = sourceTask.Status,
                    Subject = sourceTask.Subject,
                    Type = sourceTask.Type,
                    WhatId = sourceTask.WhatId,
                    WhoId = clonedLeadId
                ));
            }
        }
        
        if (!tasksToInsert.isEmpty()) {
            insert as user tasksToInsert;
        }
    }
    
    private static void copyEvents(Map<Id, Id> sourceLeadIdByClonedLeadId) {
        List<Event> eventsToInsert = new List<Event>();
        
        for (Event sourceEvent : [
            SELECT
            Description,
            EndDateTime,
            IsAllDayEvent,
            IsPrivate,
            IsReminderSet,
            Location,
            OwnerId,
            ReminderDateTime,
            ShowAs,
            StartDateTime,
            Subject,
            Type,
            WhatId,
            WhoId
            FROM Event
            WHERE WhoId IN :sourceLeadIdByClonedLeadId.values()
            WITH USER_MODE
        ]) {
            for (Id clonedLeadId : sourceLeadIdByClonedLeadId.keySet()) {
                if (sourceLeadIdByClonedLeadId.get(clonedLeadId) != sourceEvent.WhoId) {
                    continue;
                }
                
                eventsToInsert.add(new Event(
                    Description = sourceEvent.Description,
                    EndDateTime = sourceEvent.EndDateTime,
                    IsAllDayEvent = sourceEvent.IsAllDayEvent,
                    IsPrivate = sourceEvent.IsPrivate,
                    IsReminderSet = sourceEvent.IsReminderSet,
                    Location = sourceEvent.Location,
                    OwnerId = sourceEvent.OwnerId,
                    ReminderDateTime = sourceEvent.ReminderDateTime,
                    ShowAs = sourceEvent.ShowAs,
                    StartDateTime = sourceEvent.StartDateTime,
                    Subject = sourceEvent.Subject,
                    Type = sourceEvent.Type,
                    WhatId = sourceEvent.WhatId,
                    WhoId = clonedLeadId
                ));
            }
        }
        
        if (!eventsToInsert.isEmpty()) {
            insert as user eventsToInsert;
        }
    }
    private static void copyEmailMessages(Map<Id, Id> sourceLeadIdByClonedLeadId) {
        Map<Id, Id> sourceToCloneLead = new Map<Id, Id>();
        
        for (Id cloneLeadId : sourceLeadIdByClonedLeadId.keySet()) {
            sourceToCloneLead.put(sourceLeadIdByClonedLeadId.get(cloneLeadId), cloneLeadId);
        }
        
        List<EmailMessage> sourceEmails = [
            SELECT Id, Subject, HtmlBody, TextBody, Headers, FromName, FromAddress,
            ValidatedFromAddress, ToAddress, CcAddress, BccAddress,
            Incoming, Status, MessageDate, MessageIdentifier
            FROM EmailMessage
            WHERE Id IN (
                SELECT EmailMessageId
                FROM EmailMessageRelation 
                WHERE RelationId IN :sourceLeadIdByClonedLeadId.values()
            )
            WITH USER_MODE
        ];
        
        List<EmailMessage> emailsToInsert = new List<EmailMessage>();
        List<Id> sourceEmailIds = new List<Id>();
        
        for (EmailMessage sourceEmail : sourceEmails) {
            
            emailsToInsert.add(new EmailMessage(
                Subject = sourceEmail.Subject,
                HtmlBody = sourceEmail.HtmlBody,
                TextBody = sourceEmail.TextBody,
                Headers = sourceEmail.Headers,
                FromName = sourceEmail.FromName,
                FromAddress = sourceEmail.FromAddress,
                ToAddress = sourceEmail.ToAddress,
                CcAddress = sourceEmail.CcAddress,
                BccAddress = sourceEmail.BccAddress,
                Incoming = sourceEmail.Incoming,
                Status = sourceEmail.Status,
                MessageDate = sourceEmail.MessageDate,
                MessageIdentifier = sourceEmail.MessageIdentifier
            ));
            
            sourceEmailIds.add(sourceEmail.Id);
        }
        
        if (emailsToInsert.isEmpty()) {
            return;
        }
        
        insert as user emailsToInsert;
        
        // Copy Files attached to the source EmailMessage
        Map<Id, List<ContentDocumentLink>> emailFileLinkMap =
            new Map<Id, List<ContentDocumentLink>>();
        
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId, LinkedEntityId, ShareType, Visibility
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :sourceEmailIds
            WITH USER_MODE
        ]) {
            if (!emailFileLinkMap.containsKey(cdl.LinkedEntityId)) {
                emailFileLinkMap.put(
                    cdl.LinkedEntityId,
                    new List<ContentDocumentLink>()
                );
            }
            
            emailFileLinkMap.get(cdl.LinkedEntityId).add(cdl);
        }
        
        List<ContentDocumentLink> emailFileLinksToInsert =
            new List<ContentDocumentLink>();
        
        for (Integer i = 0; i < sourceEmailIds.size(); i++) {
            
            Id sourceEmailId = sourceEmailIds[i];
            Id newEmailId = emailsToInsert[i].Id;
            
            if (!emailFileLinkMap.containsKey(sourceEmailId)) {
                continue;
            }
            
            for (ContentDocumentLink sourceLink :
                 emailFileLinkMap.get(sourceEmailId)) {
                     
                     emailFileLinksToInsert.add(new ContentDocumentLink(
                         ContentDocumentId = sourceLink.ContentDocumentId,
                         LinkedEntityId = newEmailId,
                         ShareType = sourceLink.ShareType,
                         Visibility = sourceLink.Visibility
                     ));
                 }
        }
        
        if (!emailFileLinksToInsert.isEmpty()) {
            insert as user emailFileLinksToInsert;
        }
        
        // Existing EmailMessageRelation logic
        Map<Id, List<EmailMessageRelation>> relationMap =
            new Map<Id, List<EmailMessageRelation>>();
        
        for (EmailMessageRelation rel : [
            SELECT EmailMessageId, RelationId, RelationType, RelationAddress
            FROM EmailMessageRelation
            WHERE EmailMessageId IN :sourceEmailIds
            WITH USER_MODE
        ]) {
            if (!relationMap.containsKey(rel.EmailMessageId)) {
                relationMap.put(
                    rel.EmailMessageId,
                    new List<EmailMessageRelation>()
                );
            }
            
            relationMap.get(rel.EmailMessageId).add(rel);
        }
        
        List<EmailMessageRelation> relationsToInsert =
            new List<EmailMessageRelation>();
        
        for (Integer i = 0; i < sourceEmailIds.size(); i++) {
            
            Id sourceEmailId = sourceEmailIds[i];
            Id newEmailId = emailsToInsert[i].Id;
            
            if (!relationMap.containsKey(sourceEmailId)) {
                continue;
            }
            
            for (EmailMessageRelation rel : relationMap.get(sourceEmailId)) {
                
                Id relationId = rel.RelationId;
                
                if (sourceToCloneLead.containsKey(relationId)) {
                    relationId = sourceToCloneLead.get(relationId);
                }
                
                relationsToInsert.add(new EmailMessageRelation(
                    EmailMessageId = newEmailId,
                    RelationId = relationId,
                    RelationType = rel.RelationType,
                    RelationAddress = rel.RelationAddress
                ));
            }
        }
        
        if (!relationsToInsert.isEmpty()) {
            insert as user relationsToInsert;
        }
    }
}