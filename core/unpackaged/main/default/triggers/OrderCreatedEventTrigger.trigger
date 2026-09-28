/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @description
 * @date 13.03.2024 <p/>
 * @test OrderCreatedEventTrigger_TEST
 *
 */

trigger OrderCreatedEventTrigger on OrderSummaryCreatedEvent (after insert) {
	new OrderCreatedEventTriggerHandler().run();
}