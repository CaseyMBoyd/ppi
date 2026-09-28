/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @description
 * @date 03.05.2024 <p/>
 * @test CartTrigger_TEST
 *
 */

trigger CartTrigger on WebCart (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
	new CartTriggerHandler().run();
}