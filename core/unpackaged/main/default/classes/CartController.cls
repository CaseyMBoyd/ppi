/**
 * Copyright (c) 2023 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author Jakub Cichacki/Forefront
 * @version 1.0
 * @description
 *
 * PURPOSE
 *
 *
 *
 * TEST CLASS
 *
 * CartController_TEST
 *
 * CHANGE LOG
 *
 *    [Version; Date; Author; Description]
 *    v1.0; 13.03.2023; Jakub Cichacki/Forefront; Initial Build
 *
 **/
public with sharing class CartController {

	@AuraEnabled
	public static List<WebCart> fetchCarts(Id effectiveAccountId) {
		try {
			return CartService.getInstance().getCarts(effectiveAccountId);
		}
		catch (Exception e) {
			throw new AuraHandledException(AuraHandledExceptionBuilder.buildClientMessage(e));
		}
	}

	@AuraEnabled
	public static void makeCartPrimary(Id cartId) {
		Savepoint sp = Database.setSavepoint();
		try {
			CartService.getInstance().makeCartPrimary(cartId);
		}
		catch (Exception e) {
			Database.rollback(sp);
			throw new AuraHandledException(AuraHandledExceptionBuilder.buildClientMessage(e));
		}
	}

	@AuraEnabled
	public static ConnectApi.CartSummary createPrimaryCart(String cartName, Id accountId) {
		try {
			ConnectApi.CartSummary summary = CartService.getInstance().createCart(cartName, accountId);
			makeCartPrimary(summary.cartId);
			return summary;
		}
		catch (Exception e) {
			throw new AuraHandledException(AuraHandledExceptionBuilder.buildClientMessage(e));
		}
	}

	@AuraEnabled
	public static void deleteCart(Id cartId) {
		try {
            preventRecreatingNewCartWithSameName();
			CartService.getInstance().deleteCart(cartId);
		}
		catch (Exception e) {
			throw new AuraHandledException(
				AuraHandledExceptionBuilder.buildClientMessage(e)
			);
		}
	}

	@AuraEnabled
	public static void deleteCarts(List<Id> cartIds) {
		try {
            preventRecreatingNewCartWithSameName();
			CartService.getInstance().deleteCarts(cartIds);
		}
		catch (Exception e) {
			throw new AuraHandledException(
				AuraHandledExceptionBuilder.buildClientMessage(e)
			);
		}
	}

    @AuraEnabled
	public static void updateCartNames(List<WebCart> carts) {
		List<WebCart> sanitized = new List<WebCart>();

		for (WebCart cart : carts) {
			sanitized.add(
				new WebCart(
					Id = cart.Id,
					Name = cart.Name
				)
			);
		}

		update sanitized;
	}

    private static void preventRecreatingNewCartWithSameName() {
        TriggerHandler.bypass('CartTriggerHandler');
    }

	@AuraEnabled
	public static Boolean isCartEmpty() {
		Id cartId = CartService.getInstance().getPrimaryCartId();
		return CartService.getInstance().isCartEmpty(cartId);
	}
}