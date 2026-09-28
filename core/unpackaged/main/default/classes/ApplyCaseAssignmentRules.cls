/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @date 03.07.2024
 **/
public without sharing class ApplyCaseAssignmentRules {

	@InvocableMethod
	public static void assignCases(List<Case> cases) {
		Id activeAssignmentRuleId = [
			SELECT Id
			FROM AssignmentRule
			WHERE SobjectType = 'Case' AND Active = TRUE
			WITH SYSTEM_MODE
			LIMIT 1
		]?.Id;

		Database.DMLOptions dmlOpts = new Database.DMLOptions();

		dmlOpts.emailHeader.triggerAutoResponseEmail = true;
		dmlOpts.emailHeader.triggerUserEmail = true;
		dmlOpts.assignmentRuleHeader.assignmentRuleId = activeAssignmentRuleId;

		Database.update(cases, dmlOpts, AccessLevel.SYSTEM_MODE);
	}
}