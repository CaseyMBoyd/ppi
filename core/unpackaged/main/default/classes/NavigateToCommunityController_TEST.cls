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
	*   Controller for NavigateToCommunityController_TEST
	* 
	* TEST CLASS 
	* 
	*   NavigateToCommunityController_TEST_TEST
	* 
	* CHANGE LOG 
	* 
	*    [Version; Date; Author; Description]
	*    v1.0; 3/27/2024; snguyen/Forefront; Initial Build
	* 
**/
@IsTest
private class NavigateToCommunityController_TEST {
    @IsTest
    static void testGetCommunityUrl() {
        // given
        NavigateToCommunityController navigateToCommunityController = new NavigateToCommunityController();
        navigateToCommunityController.pageRoute = '/test';
        navigateToCommunityController.urlParams = 'test1;test2';
        navigateToCommunityController.isDetailPage = true;
        navigateToCommunityController.recordId = 'test';
        navigateToCommunityController.routeUsesTabset = false;
        navigateToCommunityController.communityName = 'test';

        // when
        String comUrl = navigateToCommunityController.getCommunityUrl();

        // then
        Assert.isNotNull(comUrl);
    }
}