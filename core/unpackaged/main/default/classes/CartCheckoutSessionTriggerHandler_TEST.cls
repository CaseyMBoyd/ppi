/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @date 16.03.2024
 * @description Test suite
 *
 */

@IsTest
private class CartCheckoutSessionTriggerHandler_TEST {
	@IsTest
	static void testBehavior() {
		// given
		WebCart cart = CartDocumentUploadController_TEST.arrangeCart();

		CartDocumentUploadController.FileWrapper fileInput = CartDocumentUploadController_TEST.arrangeFileInput(cart);
		CartDocumentUploadController.createCartDocument(fileInput);

		CartCheckoutSession checkoutSession = new CartCheckoutSession(
			Name = 'test_checkout_session',
			State = 'Start',
			WebCartId = cart.Id
		);
		insert checkoutSession;

		Order order = new Order(
			AccountId = cart.AccountId,
			EffectiveDate = Date.today(),
			Status = 'Draft'
		);
		insert order;

		// when
		Test.startTest();
		{
			checkoutSession.OrderId = order.Id;
			update checkoutSession;
		}
		Test.stopTest();

		// then
		Assert.areEqual(1, [
			SELECT COUNT()
			FROM ContentDocumentLink
			WHERE LinkedEntityId = :order.Id
		], 'Order should have 1 file attached');
	}
}