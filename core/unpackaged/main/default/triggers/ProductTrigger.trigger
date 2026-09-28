/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/forefront
 * @date 29.07.2024
 * @test ProductTrigger_TEST
 * 
 **/

trigger ProductTrigger on Product2 (
	before insert,
	before update,
	before delete,
	after insert,
	after update,
	after delete,
	after undelete
) {
	new ProductTriggerHandler().run();
}