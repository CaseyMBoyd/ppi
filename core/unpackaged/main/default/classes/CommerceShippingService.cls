/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @description
 * @date 23.02.2024 <p/>
 * @test CommerceShippingService_TEST
 *
 */

public without sharing class CommerceShippingService extends CartExtension.ShippingCartCalculator {


	@TestVisible private static final String ERROR_NO_SHIPPING_METHODS_FOUND = 'No applicable shipping methods found';
	@TestVisible private static final String ERROR_NO_DELIVERY_GROUPS_FOUND = 'No Cart Delivery Groups have been defined';

	public virtual override void calculate(CartExtension.CartCalculateCalculatorRequest request) {
		CartExtension.Cart cart = request.getCart();

		CartExtension.CartValidationOutputList cartValidationOutputList = cart.getCartValidationOutputs();
		purgeExistingShippingErrors(cartValidationOutputList);

		CartExtension.CartDeliveryGroupList cartDeliveryGroups = cart.getCartDeliveryGroups();

		if (cartDeliveryGroups.isEmpty()) {
			addError(ERROR_NO_DELIVERY_GROUPS_FOUND, cartValidationOutputList);
		}
		else {
			Iterator<CartExtension.CartDeliveryGroup> deliveryGroupsIterator = cartDeliveryGroups.iterator();

			List<OrderDeliveryMethod> deliveryMethods = [
				SELECT Id,
					Name,
					Carrier,
					ClassOfService,
					ProductId
				FROM OrderDeliveryMethod
				WHERE IsActive = TRUE
				AND ProductId != NULL
				WITH SYSTEM_MODE
				ORDER BY Name ASC
			];

			if (deliveryMethods.isEmpty()) {
				addError(ERROR_NO_SHIPPING_METHODS_FOUND, cartValidationOutputList);
				return;
			}

			while (deliveryGroupsIterator.hasNext()) {
				CartExtension.CartDeliveryGroup cartDeliveryGroup = deliveryGroupsIterator.next();

				CartExtension.CartDeliveryGroupMethodList cartDeliveryGroupMethods = cartDeliveryGroup.getCartDeliveryGroupMethods();

				purgeExistingDeliveryMethods(cartDeliveryGroupMethods, cartDeliveryGroup);

				for (OrderDeliveryMethod deliveryMethod : deliveryMethods) {
					CartExtension.CartDeliveryGroupMethod methodDAO =
						new CartExtension.CartDeliveryGroupMethod(deliveryMethod.Name, 0, deliveryMethod.ProductId);
					methodDAO.setCarrier(deliveryMethod.Carrier);
					methodDAO.setClassOfService(deliveryMethod.ClassOfService);

					cartDeliveryGroupMethods.add(methodDAO);
				}
			}
		}
	}

	private static void addError(String message, CartExtension.CartValidationOutputList cartValidationOutputList) {
		CartExtension.CartValidationOutput cvo = new CartExtension.CartValidationOutput(CartExtension.CartValidationOutputTypeEnum.SHIPPING,
			CartExtension.CartValidationOutputLevelEnum.ERROR);
		cvo.setMessage(message);
		cartValidationOutputList.add(cvo);
	}

	private static void purgeExistingDeliveryMethods(CartExtension.CartDeliveryGroupMethodList cartDeliveryGroupMethods, CartExtension.CartDeliveryGroup cartDeliveryGroup) {
		for (Integer j = (cartDeliveryGroupMethods.size() - 1); j >= 0; j--) {
			CartExtension.CartDeliveryGroupMethod method = cartDeliveryGroupMethods.get(j);
			cartDeliveryGroupMethods.remove(method);
		}
		cartDeliveryGroup.setSelectedCartDeliveryGroupMethod(null);
	}

	private static void purgeExistingShippingErrors(CartExtension.CartValidationOutputList cartValidationOutputList) {
		for (Integer i = (cartValidationOutputList.size() - 1); i >= 0; i--) {
			CartExtension.CartValidationOutput cvo = cartValidationOutputList.get(i);
			if (cvo.getType() == CartExtension.CartValidationOutputTypeEnum.SHIPPING) {
				cartValidationOutputList.remove(cvo);
			}
		}
	}
}