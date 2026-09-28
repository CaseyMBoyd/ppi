/**
* @description Secure read provider for lead time guidance rules.
*              cacheable=true enables the Lightning framework to unify
*              identical wire requests across all tooltip instances on the page,
*              so the SOQL fires only once regardless of how many products are listed.
*/
public with sharing class LeadTimeMetadataControllerB2B {
    
    @AuraEnabled(cacheable=true)
    public static List<Lead_Time_Guidance__mdt> getLeadTimeGuidanceRules() {
        return [
            SELECT Location_Code__c,
            	Product_Category__c,
            	Lead_Time_Display_Value__c,
            	Is_Fallback__c
            FROM   Lead_Time_Guidance__mdt
            WHERE  Is_Active__c = true
            WITH   USER_MODE
            ORDER BY Location_Code__c ASC
        ];
    }
}