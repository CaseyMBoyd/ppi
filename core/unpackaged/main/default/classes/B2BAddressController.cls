/**
* @description Controller class to fetch, filter, and sort ContactPointAddress records
for B2B LWR Portal.
* @author Salesforce B2B Solutions Architect
*/
public with sharing class B2BAddressController {
    private static final Set <String> ALLOWED_SORT_FIELDS = new Set <String> {
        'LastUsedDate__c', 'Name', 'City', 'Street'
    };
    private static final Set <String> ALLOWED_SORT_DIRECTIONS = new Set <String> {
         'ASC', 'DESC'
    };
    /**
	* @description Data Transfer Object (DTO) wrapping the frontend query parameters.
	*/
    public class AddressQueryRequest {
    	@AuraEnabled public String accountId {get; set; }
        @AuraEnabled public String searchTerm {get; set; }
        @AuraEnabled public String sortBy {get; set; }
        @AuraEnabled public String sortDirection { get; set; }
    }
    /**
	* @description Dynamic query execution to retrieve account shipping addresses with SQL-injection protection.
	* @param request Encapsulated search parameters.
	* @return List of matched ContactPointAddress records.
	*/
    @AuraEnabled(cacheable = true)
    public static List < ContactPointAddress > getShippingAddresses(AddressQueryRequest request) {
        try {
            if (request == null || String.isBlank(request.accountId)) {
                throw new AuraHandledException('Account ID is required.');
            }
            String fieldToSort = 'Name';
            String dirToSort = 'ASC';
            
            if (String.isNotBlank(request.sortBy) && ALLOWED_SORT_FIELDS.contains(request.sortBy)) {                        
                        fieldToSort = request.sortBy;
                }
            if (String.isNotBlank(request.sortDirection) &&
                ALLOWED_SORT_DIRECTIONS.contains(request.sortDirection.toUpperCase())) {
                    dirToSort = request.sortDirection.toUpperCase();
                }
            
            String accountId = request.accountId;
            String bindSearchTerm = '%' + (String.isNotBlank(request.searchTerm) ? request.searchTerm.trim() : '') + '%';
            
            String query = 'SELECT Id, Name, Street, City, State, PostalCode, Country, IsDefault, LastUsedDate__c ' +
                'FROM ContactPointAddress ' +
                'WHERE ParentId = :accountId ' +
                'AND AddressType = \'Shipping\' ' +
                'AND (Name LIKE :bindSearchTerm OR Street LIKE :bindSearchTerm OR City LIKE: bindSearchTerm) ' +
                'WITH USER_MODE ' +
                'ORDER BY ' + fieldToSort + ' ' + dirToSort + ' NULLS LAST';
            return Database.query(query);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void saveSelectedAddressId(String cartId, String addressId) {
        System.debug('cartId---'+cartId);
        System.debug('addressId---'+addressId);
        if (String.isBlank(cartId) || String.isBlank(addressId)) {
            throw new AuraHandledException('cartId and addressId are required.');
        }
		
        // Find the delivery group for this cart — there is normally one per cart
        List<CartDeliveryGroup> cartGroups = [
            SELECT Id, ContactPointAddressId__c
            FROM   CartDeliveryGroup
            WHERE  CartId = :cartId
            WITH   USER_MODE
            LIMIT  1
        ];

        System.debug('cartGroups---'+cartGroups);
        if (cartGroups.isEmpty()) {
            throw new AuraHandledException(
                'No CartDeliveryGroup found for cartId: ' + cartId
            );
        }

        ContactPointAddress address = [
            SELECT Id, Street, City, PostalCode, State, Country, Name, StateCode, CountryCode, AddressFirstName, AddressLastName, CompanyName
            FROM   ContactPointAddress
            WHERE  Id = :addressId
            WITH   USER_MODE
            LIMIT  1
        ];

        CartDeliveryGroup cartGroup = cartGroups[0];
        cartGroup.ContactPointAddressId__c = addressId;
        if(address.CompanyName != null) {
            cartGroup.CompanyName = address.CompanyName;
            cartGroup.DeliverToName = address.CompanyName;
        } else {
            cartGroup.CompanyName = address.Name;
            cartGroup.DeliverToName = address.Name;
        }
        cartGroup.DeliverToFirstName = address.AddressFirstName;
        cartGroup.DeliverToLastName = address.AddressLastName;
        cartGroup.DeliverToStreet = address.Street;
        cartGroup.DeliverToCity = address.City;
        cartGroup.DeliverToPostalCode = address.PostalCode;
        cartGroup.DeliverToState = address.State;
        cartGroup.DeliverToStateCode = address.StateCode;
        cartGroup.DeliverToCountry = address.Country;
        cartGroup.DeliverToCountryCode = address.CountryCode;

        update cartGroup;
    }
}