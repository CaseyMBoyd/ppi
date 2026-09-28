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
	*   Controller for EmailImageController
	* 
	* TEST CLASS 
	* 
	*   EmailImageController_TEST
	* 
	* CHANGE LOG 
	* 
	*    [Version; Date; Author; Description]
	*    v1.0; 5/3/2024; snguyen/Forefront; Initial Build
	* 
**/
public with sharing class EmailImageController {
    public String communityName { get; set; }
    public String imageName { get; set; }
    public String alternativeText { get; set; }

    public String getImageUrl() {
        String siteId = Test.isRunningTest() ? '' : [SELECT Id FROM Site WHERE Name =: communityName].Id;
        return createUrl(siteId);
    }

    public String createUrl(String siteId) {
        String url = Test.isRunningTest() ? '' : [SELECT SecureUrl FROM SiteDetail WHERE DurableId =: siteId].SecureUrl + '/sfsites/c/file-asset-public/' + imageName;
        return url;
    }
}