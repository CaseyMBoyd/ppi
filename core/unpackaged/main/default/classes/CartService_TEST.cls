/**
	* Copyright (c) 2023 ForeFront, Inc. All Rights Reserved.
	* Subject to ForeFront, Inc. licensing.
	*
	* @author jakub_cichacki/Forefront
	* @version 1.0
	* @description
	*
	* PURPOSE
	*
	*
	*
	* TEST CLASS
	*
	*
	*
	* ENTRY POINTS
	*
	*
	*
	* CHANGE LOG
	*
	*    [Version; Date; Author; Description]
	*    v1.0; 13.03.2023; jakub_cichacki/Forefront; Initial Build
	*
**/
@IsTest
private class CartService_TEST {
    @IsTest
    static void getCartsTest() {
        //given
        b2btd.xAccount account = new b2btd.xAccount();

        User user = (User) new b2btd.xUser().persist();

        b2btd.xCart cart = new b2btd.xCart()
                .account(account)
                .withItem(new b2btd.xProduct(), 99.0, 10)
                .status('Checkout');
        cart.persist();

        DI.Mock mock = DI.mock(BuyerContext.class);
        mock.startStubbing();
        mock.when(BuyerContext.getInstance().getEffectiveAccountId()).thenReturn(account.Id);
        mock.when(BuyerContext.getInstance().getEffectiveAccount()).thenReturn(account.getRecord());
        mock.when(BuyerContext.getInstance().getUser()).thenReturn(user);
        mock.stopStubbing();


        //when
        List<WebCart> expectedCarts = CartService.getInstance().getCarts(null);

        //then
        Assert.areEqual(1, expectedCarts.size());
        Assert.isFalse(CartService.getInstance().isCartEmpty(cart.id));
        Assert.areEqual(cart.id, CartService.getInstance().getPrimaryCartId());

        CartService.getInstance().deleteCarts(new List<Id>{cart.id});
        Assert.areEqual(0, [SELECT COUNT() FROM WebCart WHERE Id =: cart.id]);
    }

    @IsTest
    static void removeAllPrimaryCartsTest() {
        //given
        b2btd.xAccount account = new b2btd.xAccount();

        b2btd.xCart cart = new b2btd.xCart()
                .account(account)
                .withItem(new b2btd.xProduct(), 99.0, 10)
                .status('Checkout');
        cart.persist();

        //when
        CartService.getInstance().removeAllPrimaryCartsForCurrentUser(account.id);
        WebCart expected = [SELECT IsSecondary FROM WebCart WHERE AccountId = :account.id];

        //then
        Assert.areEqual(true, expected.IsSecondary);
    }

    @IsTest
    static void createCartTest() {
        //given
        b2btd.xWebstore store = new b2btd.xWebstore();
        b2btd.xAccount account = new b2btd.xAccount();

        DI.Mock mock = DI.mock(BuyerContext.class);
        mock.startStubbing();
        mock.when(BuyerContext.getInstance().getWebstore()).thenReturn(store.getRecord());
        mock.when(BuyerContext.getInstance().getEffectiveAccountId()).thenReturn(account.id);
        mock.stopStubbing();

        CartService.mockCartSummary = new ConnectApi.CartSummary();

        //when
        ConnectApi.CartSummary expectedCart = CartService.getInstance().createCart('cart Test');

        //then
        System.assertNotEquals(null, expectedCart);
    }

    @IsTest
    static void makeCartPrimaryTest() {
        //given
        User user = (User) new b2btd.xUser().persist();

        b2btd.xWebstore store = new b2btd.xWebstore();
        b2btd.xAccount account = new b2btd.xAccount();

        b2btd.xCart cart = new b2btd.xCart()
            .account(account)
            .withItem(new b2btd.xProduct(), 99.0, 10)
            .status('Checkout');
        cart.persist();

        update new WebCart(OwnerId = user.Id, Id = cart.id);

        DI.Mock mock = DI.mock(BuyerContext.class);
        mock.startStubbing();
        mock.when(BuyerContext.getInstance().getWebstore()).thenReturn(store.getRecord());
        mock.when(BuyerContext.getInstance().getEffectiveAccountId()).thenReturn(account.id);
        mock.stopStubbing();


        //when
        CartService.getInstance().makeCartPrimary(cart.id);

        //then
        Assert.areEqual(UserInfo.getUserId(), [SELECT OwnerId FROM WebCart WHERE Id =: cart.id].OwnerId, 'Owner should be changed');
    }
}