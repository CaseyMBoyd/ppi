/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author jcichacki/Forefront
 * @date 22.02.2024
 *
 **/
@IsTest
private class CheckoutController_TEST {
    @TestSetup
    static void prepareData() {
        Id buyerPermissionSetId = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = :CheckoutController.BUYER_PERMISSION_SET_DEVELOPER_NAME
            LIMIT 1
        ]
        .Id;
        insert new PermissionSetAssignment(PermissionSetId = buyerPermissionSetId, AssigneeId = UserInfo.getUserId());
    }

    @IsTest
    static void testFetchShippingBlackoutDates() {
        Assert.isNotNull(CheckoutController.fetchShippingBlackoutDates());
    }

    @IsTest
    static void saveShipDateTest_Success() {
        //given
        b2btd.xWebstore store = new b2btd.xWebstore();
        b2btd.xAccount account = new b2btd.xAccount();
        b2btd.xCart cart = new b2btd.xCart().account(account).webstore(store);
        cart.persist();
        b2btd.xContact contact = new b2btd.xContact().withAccount(account);
        contact.set('MailingCountryCode', '');
        contact.set('MailingCountry', 'Poland');
        Contact con = (Contact) contact.persist();
        BuyerContext.testContact = con;

        ConnectApi.CartSummary summary = new ConnectApi.CartSummary();
        summary.cartId = cart.id;
        BuyerService.mockCartSummary = summary;
        ConnectApi.CartSummary currActiveCart = BuyerService.currentActiveCart;

        // when
        Test.startTest();
        CheckoutController.saveShipDateInformation('No later Than', System.today());

        CartDeliveryGroup cartDeliveryGroup = [
            SELECT Id, Ship_Option__c, Ship_Date__c
            FROM CartDeliveryGroup
            WHERE CartId = :cart.Id
        ];
        Test.stopTest();

        //then
        Assert.areEqual(cartDeliveryGroup.Ship_Date__c, System.today());
    }

    @IsTest
    static void saveShipDateTest_Fail() {
        // given
        Boolean exceptionThrown = false;

        // when
        try {
            CheckoutController.saveShipDateInformation('Standard', null);
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }

        // then
        Assert.isTrue(exceptionThrown);
    }

    @IsTest
    static void testUpdateThirdPartyBillingAddress() {
        // given
        WebStore store = new WebStore(Name = 'test');
        insert store;

        Account account = new Account(Name = 'testAccount');
        insert account;

        WebCart cart = new WebCart(Name = 'test', WebStoreId = store.Id, AccountId = account.Id);
        insert cart;

        CheckoutController.ThirdPartyAddress thirdPartAddress = new CheckoutController.ThirdPartyAddress();
        thirdPartAddress.company = 'ACME';
        thirdPartAddress.state = 'NJ';
        thirdPartAddress.street = 'Test Street';
        thirdPartAddress.postalCode = '07704';
        thirdPartAddress.city = 'Fair Haven';
        thirdPartAddress.street2 = 'Test Street 2';

        // when
        CheckoutController.updateShippingInformation(cart.Id, thirdPartAddress, 'Fedex', '1234567890', 'test');

        // then
        WebCart updatedCart = [
            SELECT Third_Party_Billing_StateCode__c,
                Third_Party_Billing_Company__c,
                Carrier__c,
                Carrier_Account_Number__c
            FROM WebCart
            WHERE Id = :cart.Id
        ];

        Assert.areEqual('NJ', updatedCart.Third_Party_Billing_StateCode__c);
        Assert.areEqual('Fedex', updatedCart.Carrier__c);
        Assert.areEqual('1234567890', updatedCart.Carrier_Account_Number__c);
        Assert.areEqual('ACME', updatedCart.Third_Party_Billing_Company__c);
    }

    @IsTest
    static void testSaveSplitShipmentApproval() {
        // given
        b2btd.xCart cart = new b2btd.xCart();
        cart.persist();

        Assert.isTrue([SELECT Allow_Split_Shipment__c FROM WebCart WHERE Id =: cart.id].Allow_Split_Shipment__c);

        // when
        CheckoutController.saveSplitShipmentApproval(cart.id, false);

        // then
        Assert.isFalse([SELECT Allow_Split_Shipment__c FROM WebCart WHERE Id =: cart.id].Allow_Split_Shipment__c);
    }

    @IsTest
    static void testFetchShippingCarriers() {
        Assert.isNotNull(CheckoutController.fetchShippingCarriers());
    }

    @IsTest
    static void testGetOrderDeliveryMethods() {
        CheckoutController.getOrderDeliveryMethods();
    }
}