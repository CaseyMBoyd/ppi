global class xStudio_LeadConversionMerge {
    @InvocableMethod(label='Convert Leads on Merge' description='Converts Leads when merging to Opportunities' category='Lead')
    global static void mergeLeadsToOpportunities(List<LeadMergeConversionRequest> requests) {
        LeadStatus convertStatus = [SELECT Id, ApiName FROM LeadStatus WHERE IsConverted=true WITH USER_MODE LIMIT 1];

        List<Database.LeadConvert> leadConverts = new List<Database.LeadConvert>();
        for(LeadMergeConversionRequest request : requests){
            if (request.lead.Account__c == null || request.lead.Contact__c == null) {
                throw new LeadMergeConversionException('Select an existing Account & Contact before merge/convert.');
            }

            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(request.lead.Id);
            lc.setAccountId(request.lead.Account__c);
            lc.setContactId(request.lead.Contact__c);
            lc.setConvertedStatus(convertStatus.ApiName);
            lc.setDoNotCreateOpportunity(true);
            leadConverts.add(lc);
        }

        List<Database.LeadConvertResult> lcrs = Database.convertLead(leadConverts);
        // Update remaining filtered email images from Lead to Opportunity
        List<ContentVersion> imagesToUpdate = new List<ContentVersion>();
        
        for (Integer i = 0; i < lcrs.size(); i++) {
            if (lcrs[i].isSuccess() && requests[i].opportunity != null) {
                
                Id leadId = requests[i].lead.Id;
                Id opportunityId = requests[i].opportunity;
                
                List<ContentVersion> filteredImages = [
                    SELECT Id, Filtered_Email_RecordId__c
                    FROM ContentVersion
                    WHERE Filtered_Email_RecordId__c = :String.valueOf(leadId)
                    AND Is_Filtered_Email_Image__c = true
                    AND IsLatest = true
                ];
                
                for (ContentVersion image : filteredImages) {
                    image.Filtered_Email_RecordId__c = String.valueOf(opportunityId);
                    imagesToUpdate.add(image);
                }
            }
        }
        
        if (!imagesToUpdate.isEmpty()) {
            update imagesToUpdate;
        }
    }

    global class LeadMergeConversionRequest {
        @InvocableVariable(required=true label='Lead')
        global Lead lead;

        @InvocableVariable(required=true label='Opportunity ID')
        global Id opportunity;
    }

    public class LeadMergeConversionException extends Exception {}
}