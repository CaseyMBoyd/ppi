/**
 * Copyright (c) 2022 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author jakub_cichacki/Forefront
 * @date 16.01.2023
 * @description
 **/
@IsTest
public class BuyerService_TEST {
    @IsTest
    public static void shouldReturnCurrentEffectiveAccount() {
        //given
        b2btd.xAccount acme = new b2btd.xAccount();
        b2btd.xContact contact = new b2btd.xContact().withAccount(acme);
        contact.set('MailingCountryCode', '');
        contact.set('MailingCountry', 'Poland');
        Contact con = (Contact) contact.persist();
        Id accId = [SELECT AccountId FROM Contact WHERE Id = :con.Id LIMIT 1].AccountId;
        BuyerContext.testContact = con;
        BuyerContext.mockCurrentEffectiveAccountId = acme.id;

        //when
        Account currAcc = BuyerService.effectiveAccount;
        Id currAccId = BuyerService.effectiveAccountId;

        //then
        Assert.areEqual(accId, currAcc.Id);
        Assert.areEqual(accId, currAccId);

        Boolean exThrown = false;
        try {
            Id webstoreId = BuyerService.currentWebStoreId;
        }
        catch(Exception ex) {
            exThrown = true;
        }

        Assert.isTrue(exThrown);
        Assert.areEqual(UserInfo.getUserId(), BuyerContext.getInstance().getUser().Id);
        Assert.areEqual(false, BuyerContext.isGuestUser(BuyerContext.getInstance().getUser()));
    }

    @IsTest
    public static void shouldReturnTestCurrentActiveCart() {
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

        //when
        ConnectApi.CartSummary currActiveCart = BuyerService.currentActiveCart;

        //then
        Assert.areEqual(summary, currActiveCart);
    }

    @IsTest
    public static void shouldReturnTestCurrentContact() {
        b2btd.xContact contact = new b2btd.xContact();
        Contact con = (Contact) contact.persist();
        BuyerContext.testContact = con;

        //when
        Contact actualContact = BuyerService.currentContact;

        //then
        Assert.areEqual(con.Id, actualContact.Id);
    }
}