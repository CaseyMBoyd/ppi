/**
	* Copyright (c) 2021 ForeFront, Inc. All Rights Reserved.
	* Subject to ForeFront, Inc. licensing.
	*
	* @author jclappsy/Forefront
	* @version 1.0
	* @description
**/
@IsTest
public without sharing class TestUtils {
	public class TestDataException extends Exception {
	}

	private static Integer fakeIdsCounter = 0;
	private static Integer nameIndex = 0;

	public static void assignPermissionSetToCurrentUser(String developerName) {
		Database.insert(
			new PermissionSetAssignment(
				AssigneeId = UserInfo.getUserId(),
				PermissionSetId = [
					SELECT Id FROM PermissionSet
					WHERE Name =: developerName
				]?.Id
			),
			false
		);
	}

	/**
	 * Generates fake id for given SObject prefix
	 *
	 * @param prefix
	 *
	 * @return String
	 */
	public static String generateFakeId(String prefix) {
		String numberString = String.valueOf(fakeIdsCounter++);
		return prefix + '0'.repeat(12 - numberString.length()) + numberString;
	}

	/**
	 * Generates fake id for given SObjectType
	 *
	 * @param sType
	 *
	 * @return String
	 */
	public static String generateFakeId(SObjectType sType) {
		String numberString = String.valueOf(fakeIdsCounter++);
		String prefix = sType.getDescribe().getKeyPrefix();
		return prefix + '0'.repeat(12 - numberString.length()) + numberString;
	}

	/**
	 * Generates fake ids for a set of Sobjects
	 *
	 * @param records
	 */
	public static void generateFakeId(List<SObject> records) {
		for (SObject record : records) {
			record.Id = record.Id != null
				? record.Id
				: generateFakeId(record.getSObjectType());
		}
	}

	public static final Id STANDARD_USER {
		get {
			if (STANDARD_USER == null) {
				STANDARD_USER = [
					SELECT Id
					FROM Profile
					WHERE Name = 'Standard User'
				]
					.Id;
			}
			return STANDARD_USER;
		}
		private set;
	}

	public static final Id ADMIN_USER {
		get {
			if (ADMIN_USER == null) {
				ADMIN_USER = [
					SELECT Id
					FROM Profile
					WHERE Name = 'System Administrator'
				]
					.Id;
			}
			return ADMIN_USER;
		}
		private set;
	}

	public static final Id BUYER_USER {
		get {
			if (BUYER_USER == null) {
				BUYER_USER = [
					SELECT Id
					FROM Profile
					WHERE Name = 'Buyer'
				]
					.Id;
			}
			return BUYER_USER;
		}
		private set;
	}

	public static final Id BUYER_MANAGER_USER {
		get {
			if (BUYER_MANAGER_USER == null) {
				BUYER_MANAGER_USER = [
					SELECT Id
					FROM Profile
					WHERE Name = 'Buyer Manager'
				]
					.Id;
			}
			return BUYER_MANAGER_USER;
		}
		private set;
	}

	public static final Id ROLE_PORTAL {
		get {
			if (ROLE_PORTAL == null) {
				ROLE_PORTAL = [
					SELECT Id
					FROM UserRole
					WHERE PortalType = 'None'
					LIMIT 1
				]
					.Id;
			}
			return ROLE_PORTAL;
		}
		private set;
	}
}