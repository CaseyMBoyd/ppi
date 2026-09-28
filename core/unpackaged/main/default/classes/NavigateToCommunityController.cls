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
	*   Controller for NavigateToCommunityController
	* 
	* TEST CLASS 
	* 
	*   NavigateToCommunityController_TEST
	* 
	* CHANGE LOG 
	* 
	*    [Version; Date; Author; Description]
	*    v1.0; 3/19/2024; snguyen/Forefront; Initial Build
	* 
**/
public with sharing class NavigateToCommunityController {
    public String communityName { get; set; }
    public String pageRoute { get; set; }
    public Boolean routeUsesTabset { get; set; }
    public String urlParams { get; set; }
    public String recordId { get; set; }
    public Boolean isDetailPage { get; set; }
    public Boolean isButton { get; set; }

    public String getCommunityUrl() {
        String siteId = Test.isRunningTest() ? '' : [SELECT Id FROM Site WHERE Name =: communityName].Id;
        return createUrl(siteId);
    }

    public String createUrl(String siteId) {
        String url = Test.isRunningTest() ? '' : [SELECT SecureUrl FROM SiteDetail WHERE DurableId =: siteId].SecureUrl;

        if (!String.isEmpty(pageRoute)) {
            url += '/' + pageRoute;

            if (!String.isBlank(urlParams) && urlParams.contains(';')) {
                List<String> urlParamsList = urlParams.split(';');

                url += routeUsesTabset ? '&' : '?';

                for (Integer i = 0; i < urlParamsList.size(); i++) {
                    url += i == 0 ? urlParamsList[i] : '&' + urlParamsList[i];
                }
            }

            if (isDetailPage) {
                url += '/' + recordId;
            }
        }
        return url;
    }
}