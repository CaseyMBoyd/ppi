@IsTest
private class WebDocsFileSelectorController_TEST {
  private static Integer mockStatusCode;
  private static String mockResponseBody;
  private static String mockLastRequestBody;
  private static List<String> mockRequestBodies;
  private static String mockLastEndpoint;
  private static String mockLastMethod;

  @IsTest
  static void getContentDocsReturnsStoredMetadata() {
    Opportunity opp = createOpportunityWithRelationships();
    Id contentDocumentId = createLinkedContentDocument(
      opp.Id,
      'quote-file.pdf'
    );
    ContentVersion latestVersion = [
      SELECT Id
      FROM ContentVersion
      WHERE ContentDocumentId = :contentDocumentId
      ORDER BY VersionNumber DESC
      LIMIT 1
    ];

    update as system new ContentVersion(
      Id = latestVersion.Id,
      WebDocs_File_Name__c = 'RFQ',
      WebDocs_Sync_Status__c = 'Success',
      WebDocs_Hidden__c = true
    );

    Test.startTest();
    List<WebDocsFileSelectorController.WebDocsWrapper> webDocs = WebDocsFileSelectorController.getContentDocs(
      opp.Id
    );
    Test.stopTest();

    Assert.areEqual(1, webDocs.size(), 'Should return the linked document');
    Assert.areEqual(
      'RFQ',
      webDocs[0].webDocsName,
      'Should return the stored WebDocs file name'
    );
    Assert.isTrue(webDocs[0].isSuccess, 'Should mark a successful sync');
    Assert.isFalse(webDocs[0].isWarning, 'Success should not be warning');
    Assert.isFalse(webDocs[0].isError, 'Success should not be error');
    Assert.isTrue(webDocs[0].isHidden, 'Should return the stored hidden flag');
  }

  @IsTest
  static void updateHiddenFileStatusPersistsToContentVersion() {
    Opportunity opp = createOpportunityWithRelationships();
    Id contentDocumentId = createLinkedContentDocument(opp.Id, 'hide-me.pdf');
    ContentVersion latestVersion = [
      SELECT Id, WebDocs_Hidden__c
      FROM ContentVersion
      WHERE ContentDocumentId = :contentDocumentId
      ORDER BY VersionNumber DESC
      LIMIT 1
    ];
    Assert.isFalse(
      latestVersion.WebDocs_Hidden__c,
      'Files should start visible'
    );

    Test.startTest();
    WebDocsFileSelectorController.updateHiddenFileStatus(
      latestVersion.Id,
      true
    );
    Test.stopTest();

    ContentVersion hiddenVersion = [
      SELECT WebDocs_Hidden__c
      FROM ContentVersion
      WHERE Id = :latestVersion.Id
    ];
    Assert.isTrue(
      hiddenVersion.WebDocs_Hidden__c,
      'Should persist hidden files on the Content Version'
    );
  }

  @IsTest
  static void getContentDocsReturnsMostRecentFilesFirst() {
    Opportunity opp = createOpportunityWithRelationships();
    Id olderContentDocumentId = createLinkedContentDocument(
      opp.Id,
      'older-file.pdf'
    );
    Id newerContentDocumentId = createLinkedContentDocument(
      opp.Id,
      'newer-file.pdf'
    );
    ContentVersion olderVersion = [
      SELECT Id
      FROM ContentVersion
      WHERE ContentDocumentId = :olderContentDocumentId
      ORDER BY VersionNumber DESC
      LIMIT 1
    ];
    ContentVersion newerVersion = [
      SELECT Id
      FROM ContentVersion
      WHERE ContentDocumentId = :newerContentDocumentId
      ORDER BY VersionNumber DESC
      LIMIT 1
    ];
    Test.setCreatedDate(olderVersion.Id, DateTime.newInstance(2026, 1, 1));
    Test.setCreatedDate(newerVersion.Id, DateTime.newInstance(2026, 1, 2));

    Test.startTest();
    List<WebDocsFileSelectorController.WebDocsWrapper> webDocs = WebDocsFileSelectorController.getContentDocs(
      opp.Id
    );
    Test.stopTest();

    Assert.areEqual(2, webDocs.size(), 'Should return both linked documents');
    Assert.areEqual(
      newerContentDocumentId,
      webDocs[0].id,
      'Newest Content Version should be first'
    );
    Assert.areEqual(
      olderContentDocumentId,
      webDocs[1].id,
      'Oldest Content Version should be last'
    );
  }

  @IsTest
  static void uploadToWebDocsUsesRelationshipFieldAndUpdatesContentVersion() {
    Opportunity opp = createOpportunityWithRelationships();
    Id contentDocumentId = createLinkedContentDocument(
      opp.Id,
      'customer-po.pdf'
    );

    mockStatusCode = 200;
    mockResponseBody = '{"result":"ok"}';
    mockRequestBodies = new List<String>();
    Test.setMock(HttpCalloutMock.class, new WebDocsHttpMock());

    Test.startTest();
    WebDocsFileSelectorController.WebDocsUploadResult result = WebDocsFileSelectorController.uploadToWebDocs(
      contentDocumentId,
      'CUSTOMER PO',
      true,
      opp.Id
    );
    Test.stopTest();

    Assert.areEqual(
      2,
      mockRequestBodies.size(),
      'Should send one callout per order number relationship'
    );
    Map<String, Object> firstRequestBody = (Map<String, Object>) JSON.deserializeUntyped(
      mockRequestBodies[0]
    );
    Map<String, Object> secondRequestBody = (Map<String, Object>) JSON.deserializeUntyped(
      mockRequestBodies[1]
    );
    Assert.areEqual(
      'ORDERM',
      firstRequestBody.get('folder2'),
      'Should use the order folder when order numbers exist'
    );
    Assert.areEqual(
      '500000',
      firstRequestBody.get('keyword1'),
      'Should send the first order relationship in its own callout'
    );
    Assert.areEqual(
      'Q-100;Q-101',
      firstRequestBody.get('keyword2'),
      'Should include only the first relationship quote numbers'
    );
    Assert.areEqual(
      'PO-9',
      firstRequestBody.get('keyword3'),
      'Should include only the first relationship PO numbers'
    );
    Assert.areEqual(
      '1234',
      firstRequestBody.get('keyword4'),
      'Should continue deriving the customer number from the account'
    );
    Assert.areEqual(
      '500001',
      secondRequestBody.get('keyword1'),
      'Should send the second order relationship in its own callout'
    );
    Assert.areEqual(
      'Q-200',
      secondRequestBody.get('keyword2'),
      'Should include only the second relationship quote number'
    );
    Assert.areEqual(
      'PO-10',
      secondRequestBody.get('keyword3'),
      'Should include only the second relationship PO number'
    );
    Assert.areEqual('PUT', mockLastMethod, 'Should upload files with PUT');
    Assert.isTrue(
      mockLastEndpoint.endsWith('/webdocs/checkin?revise=true'),
      'Should request revise mode when update is checked'
    );

    ContentVersion latestVersion = [
      SELECT WebDocs_File_Name__c, WebDocs_Sync_Status__c
      FROM ContentVersion
      WHERE ContentDocumentId = :contentDocumentId
      ORDER BY VersionNumber DESC
      LIMIT 1
    ];
    Assert.isTrue(result.success, 'Successful responses should return success');
    Assert.areEqual(
      'success',
      result.status,
      'Successful responses should normalize the status'
    );
    Assert.areEqual(
      'File uploaded to WebDocs for 2 order relationships.',
      result.message,
      'Should summarize the multi-callout success'
    );
    Assert.areEqual(
      'CUSTOMER PO',
      latestVersion.WebDocs_File_Name__c,
      'Should persist the selected file name'
    );
    Assert.areEqual(
      'Success',
      latestVersion.WebDocs_Sync_Status__c,
      'Should persist the successful sync status'
    );
  }

  @IsTest
  static void uploadToWebDocsWarnsWhenNoFileNameIsProvided() {
    Opportunity opp = createOpportunityWithRelationships();
    Id contentDocumentId = createLinkedContentDocument(
      opp.Id,
      'missing-name.pdf'
    );

    Test.startTest();
    WebDocsFileSelectorController.WebDocsUploadResult result = WebDocsFileSelectorController.uploadToWebDocs(
      contentDocumentId,
      null,
      false,
      opp.Id
    );
    Test.stopTest();

    ContentVersion latestVersion = [
      SELECT WebDocs_File_Name__c, WebDocs_Sync_Status__c
      FROM ContentVersion
      WHERE ContentDocumentId = :contentDocumentId
      ORDER BY VersionNumber DESC
      LIMIT 1
    ];
    Assert.isFalse(result.success, 'Missing file names should not upload');
    Assert.areEqual(
      'warning',
      result.status,
      'Missing file names should return a warning status'
    );
    Assert.areEqual(
      'Warning',
      latestVersion.WebDocs_Sync_Status__c,
      'Should persist the warning status'
    );
  }

  @IsTest
  static void uploadToWebDocsPersistsErrorWhenAllRelationshipsFail() {
    Opportunity opp = createOpportunityWithRelationships();
    Id contentDocumentId = createLinkedContentDocument(
      opp.Id,
      'failed-upload.pdf'
    );

    mockStatusCode = 500;
    mockResponseBody = 'WebDocs unavailable';
    mockRequestBodies = new List<String>();
    Test.setMock(HttpCalloutMock.class, new WebDocsHttpMock());

    Test.startTest();
    WebDocsFileSelectorController.WebDocsUploadResult result = WebDocsFileSelectorController.uploadToWebDocs(
      contentDocumentId,
      'RFQ',
      false,
      opp.Id
    );
    Test.stopTest();

    ContentVersion latestVersion = [
      SELECT WebDocs_File_Name__c, WebDocs_Sync_Status__c
      FROM ContentVersion
      WHERE ContentDocumentId = :contentDocumentId
      ORDER BY VersionNumber DESC
      LIMIT 1
    ];
    Assert.isFalse(
      result.success,
      'Failed responses should not return success'
    );
    Assert.areEqual(
      'error',
      result.status,
      'Failed responses should normalize to an error status'
    );
    Assert.isTrue(
      result.message.contains('WebDocs upload failed for order 500000'),
      'Should include the first failed order in the message'
    );
    Assert.areEqual(
      'RFQ',
      latestVersion.WebDocs_File_Name__c,
      'Should persist the selected file name even when upload fails'
    );
    Assert.areEqual(
      'Error',
      latestVersion.WebDocs_Sync_Status__c,
      'Should persist the failed sync status'
    );
  }

  private static Opportunity createOpportunityWithRelationships() {
    Account account = new Account(
      Name = 'WebDocs Account',
      externalId__c = 123456
    );
    insert account;

    Opportunity opp = new Opportunity(
      Name = 'WebDocs Opportunity',
      AccountId = account.Id,
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30),
      Order_Number_Relationships__c = '[{"orderNumber":"500000","quoteNumbers":["Q-100","Q-101"],"poNumbers":["PO-9"]},{"orderNumber":"500001","quoteNumber":"Q-200","poNumber":"PO-10"}]'
    );
    insert opp;
    return opp;
  }

  private static Id createLinkedContentDocument(
    Id linkedEntityId,
    String fileName
  ) {
    ContentVersion version = new ContentVersion(
      ContentLocation = 'S',
      PathOnClient = fileName,
      Title = fileName,
      VersionData = Blob.valueOf('webdocs file body')
    );
    insert version;

    ContentVersion insertedVersion = [
      SELECT Id, ContentDocumentId
      FROM ContentVersion
      WHERE Id = :version.Id
    ];
    insert new ContentDocumentLink(
      LinkedEntityId = linkedEntityId,
      ContentDocumentId = insertedVersion.ContentDocumentId,
      ShareType = 'V',
      Visibility = 'AllUsers'
    );

    return insertedVersion.ContentDocumentId;
  }

  private class WebDocsHttpMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      mockLastRequestBody = req.getBody();
      if (mockRequestBodies == null) {
        mockRequestBodies = new List<String>();
      }
      mockRequestBodies.add(req.getBody());
      mockLastEndpoint = req.getEndpoint();
      mockLastMethod = req.getMethod();

      HttpResponse response = new HttpResponse();
      response.setStatusCode(mockStatusCode);
      response.setBody(mockResponseBody);
      return response;
    }
  }
}