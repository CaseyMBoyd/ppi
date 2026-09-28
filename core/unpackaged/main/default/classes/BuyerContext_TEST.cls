/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @date 01.07.2024
 * @description
 **/

@IsTest
private class BuyerContext_TEST {
	@IsTest
	static void shouldReturnCurrentEffectiveAccount() {
        BuyerService_TEST.shouldReturnCurrentEffectiveAccount();
	}

    @IsTest
    static void shouldReturnTestCurrentActiveCart() {
        BuyerService_TEST.shouldReturnTestCurrentActiveCart();
    }
    @IsTest
    static void shouldReturnTestCurrentContact() {
        BuyerService_TEST.shouldReturnTestCurrentContact();
    }

	@IsTest
	static void testGetCurrentNetwork() {
		BuyerContext context = new BuyerContext();

		Assert.isNull(context.getNetwork());
	}
}