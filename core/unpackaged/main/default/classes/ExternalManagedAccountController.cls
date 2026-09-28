public without sharing class ExternalManagedAccountController {
    @AuraEnabled(cacheable=true)
	public static string getCurrentExternalAccountName(String effectiveAccountId){
		try {
			DelegatedAccount da = [SELECT Id, Name FROM DelegatedAccount WHERE TargetId =: effectiveAccountId WITH SYSTEM_MODE LIMIT 1];
			return da.Name;
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}
}