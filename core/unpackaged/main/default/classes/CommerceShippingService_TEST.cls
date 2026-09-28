/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @date 23.02.2024
 * @description Test suite
 *
 */

@IsTest
private class CommerceShippingService_TEST {

	@IsTest
	static void testShippingMethodsAreCreated() {
		// given
		CartExtension.Cart cart = CartExtension.CartTestUtil.createCart();

		Product2 deliveryCharge = new Product2(
			Name = 'test',
			IsActive = true
		);
		insert deliveryCharge;

		List<OrderDeliveryMethod> methods = new List<OrderDeliveryMethod>{
			new OrderDeliveryMethod(
				Name = 'TestDelivery',
				ProductId = deliveryCharge.Id,
				IsActive = true
			)
		};
		insert methods;

		// Act
		Test.startTest();
		CartExtension.CartCalculateCalculatorRequest request = new CartExtension.CartCalculateCalculatorRequest(
			cart, CartExtension.OptionalBuyerActionDetails.empty()
		);
		CommerceShippingService calculator = new CommerceShippingService();
		calculator.calculate(request);
		Test.stopTest();

		// Assert
		// Test if no CVO is created
		CartExtension.CartValidationOutputList cartValidationOutputs = cart.getCartValidationOutputs();
		Assert.areEqual(0, cartValidationOutputs.size());

		// Test if CartDeliveryGroupMethod is created
		CartExtension.CartDeliveryGroupList deliveryGroups = cart.getCartDeliveryGroups();
		CartExtension.CartDeliveryGroup deliveryGroup = deliveryGroups.get(0);

		CartExtension.CartDeliveryGroupMethodList deliveryMethods = deliveryGroup.getCartDeliveryGroupMethods();

		Assert.areEqual(1, deliveryMethods.size());
		Assert.areEqual('TestDelivery', deliveryMethods.get(0).getName());
		Assert.areEqual(0, deliveryMethods.get(0).getShippingFee());
		Assert.areEqual(deliveryCharge.Id, deliveryMethods.get(0).getProductId());
	}

	@IsTest
	static void testNoCartDeliveryGroupPresent() {
		// given
		CartExtension.Cart cart = CartExtension.CartTestUtil.createCart();
		CartExtension.CartDeliveryGroupList deliveryGroups = cart.getCartDeliveryGroups();
		CartExtension.CartDeliveryGroup deliveryGroup = deliveryGroups.get(0);
		deliveryGroups.remove(deliveryGroup);

		// when
		Test.startTest();
		CartExtension.CartCalculateCalculatorRequest request = new CartExtension.CartCalculateCalculatorRequest(cart, CartExtension.OptionalBuyerActionDetails.empty());
		CommerceShippingService calculator = new CommerceShippingService();
		calculator.calculate(request);
		Test.stopTest();

		// then
		CartExtension.CartValidationOutputList cartValidationOutputs = cart.getCartValidationOutputs();
		Assert.areEqual(1, cartValidationOutputs.size());

		CartExtension.CartValidationOutput cvo = cartValidationOutputs.get(0);
		Assert.areEqual(CartExtension.CartValidationOutputTypeEnum.SHIPPING, cvo.getType());
		Assert.areEqual(CommerceShippingService.ERROR_NO_DELIVERY_GROUPS_FOUND, cvo.getMessage());
	}

	@IsTest
	static void testNoOrderDeliveryMethodsPresent() {
		// given
		CartExtension.Cart cart = CartExtension.CartTestUtil.createCart();

		// when
		Test.startTest();
		CartExtension.CartCalculateCalculatorRequest request = new CartExtension.CartCalculateCalculatorRequest(cart, CartExtension.OptionalBuyerActionDetails.empty());
		CommerceShippingService calculator = new CommerceShippingService();
		calculator.calculate(request);
		Test.stopTest();

		// then
		CartExtension.CartValidationOutputList cartValidationOutputs = cart.getCartValidationOutputs();
		Assert.areEqual(1, cartValidationOutputs.size());

		CartExtension.CartValidationOutput cvo = cartValidationOutputs.get(0);
		Assert.areEqual(CartExtension.CartValidationOutputTypeEnum.SHIPPING, cvo.getType());
		Assert.areEqual(CommerceShippingService.ERROR_NO_SHIPPING_METHODS_FOUND, cvo.getMessage());
	}
}