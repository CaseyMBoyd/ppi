/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @description
 * @date 16.03.2024 <p/>
 * @test CartCheckoutSessionTrigger_TEST
 *
 */

trigger CartCheckoutSessionTrigger on CartCheckoutSession (after update) {
	new CartCheckoutSessionTriggerHandler().run();
}