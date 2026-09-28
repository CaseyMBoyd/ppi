/**
 * Copyright (c) 2024 ForeFront, Inc. All Rights Reserved.
 * Subject to ForeFront, Inc. licensing.
 *
 * @author pjendrzyca/Forefront
 * @description
 * @date 16.03.2024 <p/>
 * @test FileUploadController_TEST
 *
 */

public without sharing class CartDocumentUploadController {

	@AuraEnabled
	public static void createCartDocument(FileWrapper fileInput) {
		Savepoint sp = Database.setSavepoint();

		try {
			Cart_Document__c cartDocument = new Cart_Document__c(
				Cart__c = fileInput.cartId
			);
			insert as system cartDocument;

			ContentVersion version = new ContentVersion(
				ContentLocation = 'S',
				PathOnClient = fileInput.name,
				Title = fileInput.name,
				VersionData = EncodingUtil.base64Decode(fileInput.base64content)
			);

			insert as system version;

			Id contentDocumentId = [
				SELECT Id,
					ContentDocumentId
				FROM ContentVersion
				WHERE Id = :version.Id
				WITH SYSTEM_MODE
			].ContentDocumentId;

			insert as system new ContentDocumentLink(
				LinkedEntityId = cartDocument.Id,
				ContentDocumentId = contentDocumentId,
				ShareType = 'V',
				Visibility = 'AllUsers'
			);
		}
		catch (Exception ex) {
			Database.rollback(sp);
			throw ex;
		}
	}

	@AuraEnabled(Cacheable=true)
	public static List<FileWrapper> fetchCartDocuments(Id cartId) {
		List<Cart_Document__c> cartDocuments = [
			SELECT Id, (SELECT Id, ContentDocument.FileType, ContentDocument.Title FROM ContentDocumentLinks)
			FROM Cart_Document__c
			WHERE Cart__c = :cartId
			WITH SYSTEM_MODE
		];

		List<FileWrapper> existingFiles = new List<FileWrapper>();

		for (Cart_Document__c cartDocument : cartDocuments) {
			for (ContentDocumentLink link : cartDocument.ContentDocumentLinks) {
				FileWrapper wrapper = new FileWrapper();
				wrapper.cartId = cartId;
				wrapper.mimeType = link.ContentDocument.FileType;
				wrapper.name = link.ContentDocument.Title;
				wrapper.cartDocumentId = cartDocument.Id;

				existingFiles.add(wrapper);
			}
		}

		return existingFiles;
	}

	@AuraEnabled
	public static void deleteCartDocument(Id cartDocumentId) {
		Savepoint sp = Database.setSavepoint();

		try {
			List<ContentDocumentLink> links = [
				SELECT ContentDocumentId
				FROM ContentDocumentLink
				WHERE LinkedEntityId = :cartDocumentId
				WITH SYSTEM_MODE
			];

			Set<Id> contentDocumentIdsToRemove = new Set<Id>();

			for (ContentDocumentLink link : links) {
				contentDocumentIdsToRemove.add(link.ContentDocumentId);
			}

			delete as system [
				SELECT Id
				FROM ContentDocument
				WHERE Id IN :contentDocumentIdsToRemove
			];
			delete as system [SELECT Id FROM Cart_Document__c WHERE Id = :cartDocumentId];
		}
		catch(Exception ex) {
			Database.rollback(sp);
			throw ex;
		}
	}

	public class FileWrapper {
		@AuraEnabled public Id cartId { get; set; }
		@AuraEnabled public Id cartDocumentId { get; set; }

		@AuraEnabled public String name { get; set; }
		@AuraEnabled public String mimeType { get; set; }
		@AuraEnabled public String base64content { get; set; }
	}
}