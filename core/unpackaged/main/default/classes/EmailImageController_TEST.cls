/**
	* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
	* Subject to ForeFront, Inc. licensing.
	*
	* @author snguyen/Forefront
	* @version 1.0
	* @description
	*
	* PURPOSE
	* 
	*   Controller for EmailImageController_TEST
	* 
	* TEST CLASS 
	* 
	*   EmailImageController_TEST_TEST
	* 
	* CHANGE LOG 
	* 
	*    [Version; Date; Author; Description]
	*    v1.0; 5/3/2024; snguyen/Forefront; Initial Build
	* 
**/
@IsTest
private class EmailImageController_TEST {
    @IsTest
    static void testGetImageUrl() {
        // given
        EmailImageController emailImageController = new EmailImageController();
        emailImageController.imageName = 'test';
        emailImageController.communityName = 'test';
        emailImageController.alternativeText = 'test';

        // when
        String imgUrl = emailImageController.getImageUrl();

        // then
        Assert.isNotNull(imgUrl);
    }
}