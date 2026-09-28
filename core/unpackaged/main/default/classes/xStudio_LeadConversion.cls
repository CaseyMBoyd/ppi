public with sharing class xStudio_LeadConversion {
    @InvocableMethod(label='Convert Leads to Opportunities' description='Converts Leads to Opportunities' category='Lead')
    public static List<Id> convertLeadsToOpportunitys(List<Lead> leads) {
        LeadStatus convertStatus = [SELECT Id, ApiName FROM LeadStatus WHERE IsConverted=true WITH USER_MODE LIMIT 1];

        List<Database.LeadConvert> leadConverts = new List<Database.LeadConvert>();
        for(Lead lead : leads){
            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(lead.Id);
            lc.setAccountId(lead.Account__c);
            lc.setContactId(lead.Contact__c);
            lc.setConvertedStatus(convertStatus.ApiName);
            leadConverts.add(lc);
        }

        List<Database.LeadConvertResult> lcrs = Database.convertLead(leadConverts);
        List<Id> newOppIds = new List<Id>();
        for(Database.LeadConvertResult lcr : lcrs){
            newOppIds.add(lcr.getOpportunityId());
        }
        return newOppIds;
    }
}