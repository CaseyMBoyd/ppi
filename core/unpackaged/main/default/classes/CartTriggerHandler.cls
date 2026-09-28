/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @description
 * @date 03.05.2024 <p/>
 * @test CartTriggerHandler_TEST
 *
 */

public without sharing class CartTriggerHandler extends TriggerHandler {

	@TestVisible
	private static final String PENDING_DELETE_CART_STATUS = 'PendingDelete';

	protected override void afterUpdate() {
		createNewCartWhenStatusPendingDelete((Map<Id, WebCart>) Trigger.oldMap, Trigger.new);
	}

	private static void createNewCartWhenStatusPendingDelete(Map<Id, WebCart> oldMap, List<WebCart> newList) {
		try {
			for (WebCart cart : newList) {
				if (cart.Status != oldMap.get(cart.Id).Status && cart.Status == PENDING_DELETE_CART_STATUS) {
					ConnectApi.CartSummary cartSummary = CartService.getInstance().createCart(cart.Name, cart.AccountId);
					CartService.getInstance().makeCartPrimary(cartSummary.cartId);
				}
			}
		}
		catch (Exception e) {
			Logger.error('Error WebCartTriggerHandler', e);
			Logger.saveLog();
		}
	}

}