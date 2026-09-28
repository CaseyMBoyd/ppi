/**
* @description Service Domain utility class for bulk translation of raw ERP
*              warehouse codes into sanitized portal display labels.
*              Uses static caching so the SOQL fires only once per transaction.
*/
public with sharing class InventoryLocationTransformer {
    
    // Static variables — survive for the lifetime of the Apex transaction.
    // initializeCache() checks these before querying so SOQL runs only once.
    private static Map<String, Inventory_Location_Mapping__mdt> activeMappingsCache;    
    /**
    * Loads all active mappings and the fallback record into static memory.
    * The null-check ensures this runs at most once per transaction.
    */
    private static void initializeCache() {
        
        if (activeMappingsCache == null) {
            
            activeMappingsCache =
                new Map<String, Inventory_Location_Mapping__mdt>();
            
            for (Inventory_Location_Mapping__mdt mapping : [
                SELECT MasterLabel,
                ERP_Location_Code__c,
                Portal_Display_Name__c,
                Is_Fallback_Default__c,
                Is_Active__c
                FROM Inventory_Location_Mapping__mdt
                WHERE Is_Active__c = true
                WITH USER_MODE
            ]) {
                // Match using ERP Location Code
                if (String.isNotBlank(mapping.ERP_Location_Code__c)) {
                    activeMappingsCache.put(mapping.ERP_Location_Code__c.trim().toUpperCase(),mapping);
                }
            }
        }
    }
    
    /**
    * @description Translates a set of raw ERP codes into portal display names.
    *              This is the primary method called by InventoryServiceB2B.
    * @param rawCodes  Set of raw ERP location codes from the HTTP payload
    * @return          Map of rawCode => portalDisplayName
    */
    public static Map<String, String> getFriendlyLocationNamesBulk(Set<String> rawCodes) {
        
        Map<String, String> resultMap = new Map<String, String>();
        
        if (rawCodes == null || rawCodes.isEmpty()) {
            return resultMap;
        }
        initializeCache();
        for (String rawCode : rawCodes) {

            if (String.isBlank(rawCode)) {
                resultMap.put(rawCode, rawCode);
                continue;
            }
            String sanitizedCode = rawCode.trim();
            String searchKey = sanitizedCode.toUpperCase();

            if (activeMappingsCache.containsKey(searchKey)) {
                resultMap.put( rawCode,activeMappingsCache.get(searchKey).Portal_Display_Name__c); 
            } 
        }
        return resultMap;
    }
}