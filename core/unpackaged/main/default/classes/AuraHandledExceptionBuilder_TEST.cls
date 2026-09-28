/**
	* Copyright (c) 2021 ForeFront, Inc. All Rights Reserved.
	* Subject to ForeFront, Inc. licensing.
	*
	* @author jclappsy/Forefront
	* @version 1.0
	* @description
	*
	* PURPOSE
	*
	*    Test for AuraHandledExceptionBuilder
	*
	* CHANGE LOG
	*
	*    [Version; Date; Author; Description]
	*    v1.0; 10/4/2021; jclappsy/Forefront; Initial Build
	*
**/
@IsTest
private class AuraHandledExceptionBuilder_TEST {
    @IsTest
    static void testBehavior() {
        // given
        NullPointerException nullEx = new NullPointerException();

        // when
        AuraHandledException auraEx = new AuraHandledException(
                AuraHandledExceptionBuilder.buildClientMessage(nullEx)
        );

        // then
        System.assertNotEquals(null, auraEx.getMessage());
    }
}