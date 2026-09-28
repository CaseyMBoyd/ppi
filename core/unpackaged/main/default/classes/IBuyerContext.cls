/**
	* Copyright (c) 2021 ForeFront, Inc. All Rights Reserved.
	* Subject to ForeFront, Inc. licensing.
	*
	* @author Forefront
	* @version 1.0
	* @description
	*
	* PURPOSE
	*
	*	Interface for buyer context
	*
	* CHANGE LOG
	*
	*    [Version; Date; Author; Description]
	*    v1.0; 10/11/2021; Forefront; Initial Build
	*
**/
public interface IBuyerContext {
    Id getEffectiveAccountId();
    WebStore getWebstore();
    Account getEffectiveAccount();
    Contact getContact();
    User getUser();
    Network getNetwork();
}