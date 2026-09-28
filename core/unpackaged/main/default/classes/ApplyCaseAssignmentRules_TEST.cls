/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @date 03.07.2024
 **/
@IsTest
private class ApplyCaseAssignmentRules_TEST {

	@IsTest
	static void testBehavior() {
		// given
		Case cs = new Case(
			Status = 'New',
			Subject = 'Test',
			Description = 'test'
		);
		insert cs;

		cs.Subject += 'change';

		// when
		ApplyCaseAssignmentRules.assignCases(new List<Case>{cs});

		// then
//		Assert.areNotEqual(
//			cs.Subject,
//			[SELECT Subject FROM Case WHERE Id =: cs.Id].Subject,
//			'case should be updated'
//		);

	}
}