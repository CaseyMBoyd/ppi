@IsTest
private class B2BAddressController_TEST {

    @TestSetup
    static void makeData() {
        // Create a test Account (business account)
        Account acct = new Account(Name = 'Test B2B Account');
        insert acct;

        // Create multiple ContactPointAddresses linked to the account
        List<ContactPointAddress> addresses = new List<ContactPointAddress>();

        ContactPointAddress addr1 = new ContactPointAddress(
            Name        = 'Warehouse Alpha',
            ParentId    = acct.Id,
            AddressType = 'Shipping',
            Street      = '123 Main St',
            City        = 'Des Moines',
            State       = 'IA',
            PostalCode  = '50309',
            Country     = 'US',
            LastUsedDate__c = DateTime.now().addDays(-1)
        );

        ContactPointAddress addr2 = new ContactPointAddress(
            Name        = 'Office Beta',
            ParentId    = acct.Id,
            AddressType = 'Shipping',
            Street      = '456 Oak Ave',
            City        = 'Chicago',
            State       = 'IL',
            PostalCode  = '60601',
            Country     = 'US',
            LastUsedDate__c = DateTime.now()
        );

        ContactPointAddress addr3 = new ContactPointAddress(
            Name        = 'Store Gamma',
            ParentId    = acct.Id,
            AddressType = 'Shipping',
            Street      = '789 Pine Rd',
            City        = 'Miami',
            State       = 'FL',
            PostalCode  = '33101',
            Country     = 'US',
            LastUsedDate__c = DateTime.now().addDays(-5)
        );

        addresses.add(addr1);
        addresses.add(addr2);
        addresses.add(addr3);
        insert addresses;
        
        WebStore store = new WebStore(Name = 'test');
        insert store;
        
         WebCart cart = new WebCart(
            Name      = 'Test Cart',
            AccountId = acct.Id,
            Status    = 'Active',
            WebStoreId = store.Id
        );
        insert cart;

        CartDeliveryGroup cdg = new CartDeliveryGroup(
            Name      = 'Default Delivery',
            CartId = cart.Id
        );
        insert cdg;
    }

    // Scenario 1: No search term — returns all account addresses
    @IsTest
    static void testGetAllAddresses() {
        Account acct = [SELECT Id FROM Account LIMIT 1];

        B2BAddressController.AddressQueryRequest req = new B2BAddressController.AddressQueryRequest();
        req.accountId     = acct.Id;
        req.searchTerm    = '';
        req.sortBy        = 'Name';
        req.sortDirection = 'ASC';

        Test.startTest();
        List<ContactPointAddress> result = B2BAddressController.getShippingAddresses(req);
        Test.stopTest();

        Assert.areEqual(3, result.size(), 'Should return all 3 shipping addresses');
    }

    // Scenario 2: Partial text match on Name field
    @IsTest
    static void testSearchByPartialName() {
        Account acct = [SELECT Id FROM Account LIMIT 1];

        B2BAddressController.AddressQueryRequest req = new B2BAddressController.AddressQueryRequest();
        req.accountId     = acct.Id;
        req.searchTerm    = 'Alpha';
        req.sortBy        = 'Name';
        req.sortDirection = 'ASC';

        Test.startTest();
        List<ContactPointAddress> result = B2BAddressController.getShippingAddresses(req);
        Test.stopTest();

        Assert.areEqual(1, result.size(), 'Should return only Warehouse Alpha');
        Assert.areEqual('Warehouse Alpha', result[0].Name, 'Name should match');
    }

    // Scenario 3: Sorting by LastUsedDate__c descending
    @IsTest
    static void testSortByRecencyDescending() {
        Account acct = [SELECT Id FROM Account LIMIT 1];

        B2BAddressController.AddressQueryRequest req = new B2BAddressController.AddressQueryRequest();
        req.accountId     = acct.Id;
        req.searchTerm    = '';
        req.sortBy        = 'LastUsedDate__c';
        req.sortDirection = 'DESC';

        Test.startTest();
        List<ContactPointAddress> result = B2BAddressController.getShippingAddresses(req);
        Test.stopTest();

        Assert.areEqual(3, result.size(), 'Should return all 3 addresses');
        // Most recently used (Office Beta, today) should be first
        Assert.areEqual('Office Beta', result[0].Name, 'Most recently used address should be first');
    }

    // Scenario 4: Null accountId must throw an exception
    @IsTest
    static void testNullAccountIdThrowsException() {
        B2BAddressController.AddressQueryRequest req = new B2BAddressController.AddressQueryRequest();
        req.accountId  = null;
        req.searchTerm = '';

        Test.startTest();
        try {
            B2BAddressController.getShippingAddresses(req);
            Assert.fail('Expected AuraHandledException was not thrown');
        } catch (AuraHandledException e) {
            Assert.isNotNull(e.getMessage(), 'Exception message should not be null');
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testSaveSelectedAddressIdSuccess() {
        WebCart cart = [SELECT Id FROM WebCart LIMIT 1];
        ContactPointAddress cpa = [SELECT Id FROM ContactPointAddress LIMIT 1];

        Test.startTest();
        B2BAddressController.saveSelectedAddressId(cart.Id, cpa.Id);
        Test.stopTest();

        CartDeliveryGroup updated = [
            SELECT ContactPointAddressId__c
            FROM   CartDeliveryGroup
            WHERE  CartId = :cart.Id
            LIMIT  1
        ];
        Assert.areEqual(cpa.Id, updated.ContactPointAddressId__c,
            'CPA Id should be stamped on the delivery group');
    }

    // Scenario 2: Blank cartId throws AuraHandledException
    @IsTest
    static void testBlankCartIdThrows() {
        ContactPointAddress cpa = [SELECT Id FROM ContactPointAddress LIMIT 1];
        Boolean threw = false;
        Test.startTest();
        try {
            B2BAddressController.saveSelectedAddressId('', cpa.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        Assert.isTrue(threw, 'Blank cartId must throw AuraHandledException');
    }

    // Scenario 3: Blank addressId throws AuraHandledException
    @IsTest
    static void testBlankAddressIdThrows() {
        WebCart cart = [SELECT Id FROM WebCart LIMIT 1];
        Boolean threw = false;
        Test.startTest();
        try {
            B2BAddressController.saveSelectedAddressId(cart.Id, '');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        Assert.isTrue(threw, 'Blank addressId must throw AuraHandledException');
    }

    // Scenario 4: Non-existent cartId throws AuraHandledException
    @IsTest
    static void testInvalidCartIdThrows() {
        ContactPointAddress cpa = [SELECT Id FROM ContactPointAddress LIMIT 1];
        Boolean threw = false;
        Test.startTest();
        try {
            B2BAddressController.saveSelectedAddressId('001000000000000AAA', cpa.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        Assert.isTrue(threw, 'Invalid cartId must throw AuraHandledException');
    }
}