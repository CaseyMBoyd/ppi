public without sharing class LeadTriggerHandler extends TriggerHandler {
  // Before Insert Override
  protected override void beforeInsert() {
    markClonedLeads(Trigger.new);
  }

  // After Insert Override
  protected override void afterInsert() {
    updateOriginalClonedLeads(Trigger.new);
  }

  // Before Insert: Mark cloned leads and store original Lead ID
  private static void markClonedLeads(List<Lead> newLeadList) {
    for (Lead l : newLeadList) {
      if (l.isClone()) {
        l.Is_Cloned_Lead__c = true;
        Id sourceId = l.getCloneSourceId();
        if (sourceId != null) {
          l.Cloned_From_Lead_Name__c = sourceId;
        }
      }
    }
  }

  // After Insert: Update original leads to indicate they've been cloned
  private static void updateOriginalClonedLeads(List<Lead> newLeadList) {
    Map<Id, Lead> clonedLeadsMap = new Map<Id, Lead>();
    Set<Id> sourceLeadIds = new Set<Id>();

    for (Lead l : newLeadList) {
      if (l.Is_Cloned_Lead__c && l.Cloned_From_Lead_Name__c != null) {
        Id sourceId;
        try {
          sourceId = (Id) l.Cloned_From_Lead_Name__c;
        } catch (Exception e) {
          continue;
        }
        clonedLeadsMap.put(sourceId, l);
        sourceLeadIds.add(sourceId);
      }
    }

    if (!sourceLeadIds.isEmpty()) {
      List<Lead> leadsToUpdate = new List<Lead>();
      for (Lead originalLead : [
        SELECT Id, Name, Has_Been_Cloned__c, Cloned_To_Lead_Name__c
        FROM Lead
        WHERE Id IN :sourceLeadIds
        WITH SYSTEM_MODE
      ]) {
        Lead clonedLead = clonedLeadsMap.get(originalLead.Id);
        originalLead.Has_Been_Cloned__c = true;
        originalLead.Cloned_To_Lead_Name__c = clonedLead.Name;
        leadsToUpdate.add(originalLead);
      }
      if (!leadsToUpdate.isEmpty()) {
        update as system leadsToUpdate;
      }
    }
  }
}