/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @date 03.05.2024
 * @description Test suite
 *
 */

@IsTest
private class CartTriggerHandler_TEST {
	@IsTest
	static void testCreatingNewCartWithOldNameForPendingDeleteStatus() {
		// given
		b2btd.xWebstore store = new b2btd.xWebstore();
		b2btd.xAccount account = new b2btd.xAccount();

		b2btd.xCart cart = new b2btd.xCart().account(account).webstore(store);
		String cartName = 'Test Cart';
		cart.set('Name', cartName);
		cart.persist();

		DI.Mock mock = DI.mock(BuyerContext.class);
		mock.startStubbing();
		mock.when(BuyerContext.getInstance().getWebstore()).thenReturn(store.getRecord());
		mock.when(BuyerContext.getInstance().getEffectiveAccountId()).thenReturn(account.id);
		mock.stopStubbing();

		ConnectApi.CartSummary cartSummary = new ConnectApi.CartSummary();
		CartService.mockCartSummary = cartSummary;

		// when
		update new WebCart(Id = cart.id, Status = CartTriggerHandler.PENDING_DELETE_CART_STATUS);

		// then
		Assert.isTrue([SELECT Id FROM WebCart WHERE Name = :cartName].size() > 0);
	}
}