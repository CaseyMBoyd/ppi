/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @description
 * @date 16.03.2024 <p/>
 * @test CartCheckoutSessionTriggerHandler_TEST
 *
 */

public without sharing class CartCheckoutSessionTriggerHandler extends TriggerHandler {
	protected override void afterUpdate() {
		List<CartCheckoutSession> newSessions = Trigger.new;
		Map<Id, CartCheckoutSession> oldSessions = (Map<Id, CartCheckoutSession>) Trigger.oldMap;

		Map<Id, Id> orderIdByCartId = new Map<Id, Id>();

		for (CartCheckoutSession newSession : newSessions) {
			CartCheckoutSession oldSession = oldSessions.get(newSession.Id);

			if (isOrderCreated(newSession, oldSession)) {
				orderIdByCartId.put(newSession.WebCartId, newSession.OrderId);

				if (newSessions.size() == 1) {
					tryCreateAndActivateNewCart(newSession);
				}
			}
		}

		linkCartDocumentsToOrder(orderIdByCartId);
	}

	private void tryCreateAndActivateNewCart(CartCheckoutSession newSession) {
		try {
			String cartName = [
				SELECT Name
				FROM WebCart
				WHERE Id = :newSession.WebCartId
			]?.Name ?? 'New Cart ' + Date.today();

			Order createdOrder = [
				SELECT Id,
					SalesStoreId,
					AccountId
				FROM Order
				WHERE Id = :newSession.OrderId
			];
			BuyerContext.overrideState(createdOrder.SalesStoreId, createdOrder.AccountId);

			ConnectApi.CartSummary cartSummary = CartService.getInstance().createCart(cartName);
			CartService.getInstance().makeCartPrimary(cartSummary.cartId);
		}
		catch (Exception ex) {
			Logger.error('Failed to create new cart after order place', ex).setRecord(newSession.WebCartId);
		}
		finally {
			Logger.saveLog();
		}
	}


	private void linkCartDocumentsToOrder(Map<Id, Id> orderIdByCartId) {

		List<Cart_Document__c> cartDocuments = [
			SELECT Id,
				Cart__c, (
				SELECT
					Id,
					ContentDocument.FileType,
					ContentDocument.Title
				FROM ContentDocumentLinks
			)
			FROM Cart_Document__c
			WHERE Cart__c IN :orderIdByCartId.keySet()
			WITH SYSTEM_MODE
		];

		List<ContentDocumentLink> orderLinks = new List<ContentDocumentLink>();


		for (Cart_Document__c cartDocument : cartDocuments) {
			for (ContentDocumentLink cartLink : cartDocument.ContentDocumentLinks) {

				ContentDocumentLink orderLink = new ContentDocumentLink(
					ContentDocumentId = cartLink.ContentDocumentId,
					LinkedEntityId = orderIdByCartId.get(cartDocument.Cart__c)
				);

				orderLinks.add(orderLink);
			}
		}

		insert as system orderLinks;
	}
	private Boolean isOrderCreated(CartCheckoutSession newSession, CartCheckoutSession oldSession) {
		return newSession.OrderId != oldSession.OrderId && String.isNotBlank(newSession.OrderId);
	}
}