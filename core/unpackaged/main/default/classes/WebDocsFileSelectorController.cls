public without sharing class WebDocsFileSelectorController {
  private static final String STATUS_SUCCESS = 'Success';
  private static final String STATUS_WARNING = 'Warning';
  private static final String STATUS_ERROR = 'Error';

  @AuraEnabled(cacheable=true)
  public static List<WebDocsWrapper> getContentDocs(Id recordId) {
    try {
      if (recordId == null) {
        return new List<WebDocsWrapper>();
      }

      List<ContentDocumentLink> cdls = [
        SELECT Id, ContentDocumentId, LinkedEntityId
        FROM ContentDocumentLink
        WHERE LinkedEntityId = :recordId
      ];
      Set<Id> cdIds = new Set<Id>();
      for (ContentDocumentLink cdl : cdls) {
        cdIds.add(cdl.ContentDocumentId);
      }

      if (cdIds.isEmpty()) {
        return new List<WebDocsWrapper>();
      }

      List<ContentVersion> versions = [
        SELECT
          Id,
          ContentDocumentId,
          ContentDocument.Title,
          Title,
          WebDocs_File_Name__c,
          WebDocs_Sync_Status__c,
          WebDocs_Hidden__c
        FROM ContentVersion
        WHERE ContentDocumentId IN :cdIds AND IsLatest = TRUE
        WITH SYSTEM_MODE
        ORDER BY CreatedDate DESC
      ];
      List<WebDocsWrapper> webDocs = new List<WebDocsWrapper>();
      for (ContentVersion version : versions) {
        WebDocsWrapper webDoc = new WebDocsWrapper();
        webDoc.id = version.ContentDocumentId;
        webDoc.contentVersionId = version.Id;
        webDoc.title = version.ContentDocument?.Title ?? version.Title;
        webDoc.webDocsName = version.WebDocs_File_Name__c;
        webDoc.isHidden = version.WebDocs_Hidden__c == true;
        webDoc.reviseFile = false;
        applyStatus(
          webDoc,
          normalizeStatus(version.WebDocs_Sync_Status__c, webDoc.webDocsName)
        );
        webDocs.add(webDoc);
      }
      return webDocs;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static WebDocsUploadResult uploadToWebDocs(
    Id contentDocId,
    String fileName,
    Boolean reviseFile,
    Id oppId
  ) {
    Id contentVersionId;
    String resolvedFileName;
    WebDocsUploadResult result = new WebDocsUploadResult();
    result.contentDocId = contentDocId;

    try {
      ContentDocument cd = [
        SELECT
          Id,
          LatestPublishedVersionId,
          LatestPublishedVersion.VersionData,
          LatestPublishedVersion.FileExtension,
          LatestPublishedVersion.WebDocs_File_Name__c
        FROM ContentDocument
        WHERE Id = :contentDocId
        WITH SYSTEM_MODE
      ];
      contentVersionId = cd.LatestPublishedVersionId;
      result.contentVersionId = contentVersionId;
      resolvedFileName = String.isBlank(fileName)
        ? cd.LatestPublishedVersion?.WebDocs_File_Name__c
        : fileName.trim();
      result.webDocsName = resolvedFileName;

      if (String.isBlank(resolvedFileName)) {
        updateContentVersionMetadata(
          contentVersionId,
          cd.LatestPublishedVersion?.WebDocs_File_Name__c,
          STATUS_WARNING
        );
        return buildUploadResult(
          contentDocId,
          contentVersionId,
          cd.LatestPublishedVersion?.WebDocs_File_Name__c,
          false,
          STATUS_WARNING,
          'Select a WebDocs File Name before uploading.'
        );
      }

      Opportunity opp = [
        SELECT
          Id,
          Order_Number_Relationships__c,
          Quote_Number__c,
          Order_Number__c,
          PO_Number__c,
          AccountId
        FROM Opportunity
        WHERE Id = :oppId
        WITH SYSTEM_MODE
      ];
      Account acc = [
        SELECT Id, externalId__c, Indirect_Customer_No__c, Parent.externalId__c
        FROM Account
        WHERE Id = :opp.AccountId
      ];
      String customerNumber = XaCalloutController.createCustomerNumberFromAccount(
        acc
      );
      customerNumber = customerNumber.split('-')[0];
      List<WebDocsKeywordSet> keywordSets = buildKeywordSets(
        opp.Order_Number_Relationships__c,
        opp.Order_Number__c,
        opp.Quote_Number__c,
        opp.PO_Number__c
      );

      Integer successCount = 0;
      List<String> failureMessages = new List<String>();
      for (WebDocsKeywordSet keywordSet : keywordSets) {
        HttpResponse res = sendWebDocsRequest(
          cd,
          resolvedFileName,
          customerNumber,
          reviseFile,
          keywordSet
        );

        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
          successCount++;
        } else {
          failureMessages.add(buildFailedUploadMessage(res, keywordSet));
        }
      }

      if (failureMessages.isEmpty()) {
        updateContentVersionMetadata(
          contentVersionId,
          resolvedFileName,
          STATUS_SUCCESS
        );
        return buildUploadResult(
          contentDocId,
          contentVersionId,
          resolvedFileName,
          true,
          STATUS_SUCCESS,
          keywordSets.size() == 1
            ? 'File uploaded to WebDocs.'
            : 'File uploaded to WebDocs for ' +
              String.valueOf(keywordSets.size()) +
              ' order relationships.'
        );
      }

      String resultStatus = successCount > 0 ? STATUS_WARNING : STATUS_ERROR;
      updateContentVersionMetadata(
        contentVersionId,
        resolvedFileName,
        resultStatus
      );
      return buildUploadResult(
        contentDocId,
        contentVersionId,
        resolvedFileName,
        false,
        resultStatus,
        buildRelationshipUploadMessage(
          keywordSets.size(),
          successCount,
          failureMessages
        )
      );
    } catch (Exception e) {
      if (contentVersionId != null) {
        updateContentVersionMetadata(
          contentVersionId,
          resolvedFileName,
          STATUS_ERROR
        );
      }
      return buildUploadResult(
        contentDocId,
        contentVersionId,
        resolvedFileName,
        false,
        STATUS_ERROR,
        e.getMessage()
      );
    }
  }

  @AuraEnabled
  public static void updateHiddenFileStatus(
    Id contentVersionId,
    Boolean isHidden
  ) {
    if (contentVersionId == null) {
      throw new AuraHandledException('Content Version Id is required.');
    }

    ContentVersion contentVersion = new ContentVersion(
      Id = contentVersionId,
      WebDocs_Hidden__c = isHidden == true
    );
    Database.update(contentVersion, false, AccessLevel.SYSTEM_MODE);
  }

  private static void updateContentVersionMetadata(
    Id contentVersionId,
    String fileName,
    String syncStatus
  ) {
    if (contentVersionId == null) {
      return;
    }

    ContentVersion contentVersion = new ContentVersion(Id = contentVersionId);
    if (fileName != null) {
      contentVersion.WebDocs_File_Name__c = fileName;
    }
    contentVersion.WebDocs_Sync_Status__c = syncStatus;
    Database.update(contentVersion, false, AccessLevel.SYSTEM_MODE);
  }

  private static WebDocsUploadResult buildUploadResult(
    Id contentDocId,
    Id contentVersionId,
    String fileName,
    Boolean success,
    String status,
    String message
  ) {
    WebDocsUploadResult result = new WebDocsUploadResult();
    result.contentDocId = contentDocId;
    result.contentVersionId = contentVersionId;
    result.webDocsName = fileName;
    result.success = success;
    result.status = normalizeStatus(status, fileName);
    result.message = message;
    return result;
  }

  private static HttpResponse sendWebDocsRequest(
    ContentDocument contentDocument,
    String resolvedFileName,
    String customerNumber,
    Boolean reviseFile,
    WebDocsKeywordSet keywordSet
  ) {
    Http h = new Http();
    HttpRequest req = new HttpRequest();

    String endpointString = 'callout:XA_API/webdocs/checkin';
    if (reviseFile != null && reviseFile) {
      endpointString += '?revise=true';
    }
    req.setEndpoint(endpointString);
    req.setMethod('PUT');
    req.setHeader('Content-Type', 'application/json');
    System.debug(endpointString);

    Map<String, String> putBody = new Map<String, String>();
    putBody.put(
      'file',
      EncodingUtil.base64Encode(
        contentDocument.LatestPublishedVersion.VersionData
      )
    );
    putBody.put('name', resolvedFileName);
    putBody.put(
      'docType',
      contentDocument.LatestPublishedVersion.FileExtension
    );
    putBody.put(
      'filetype',
      contentDocument.LatestPublishedVersion.FileExtension
    );
    putBody.put('folder1', 'SALES');
    putBody.put('folder2', keywordSet.folderName);
    if (!String.isBlank(keywordSet.orderNumbers)) {
      putBody.put('keyword1', keywordSet.orderNumbers);
    }
    if (!String.isBlank(keywordSet.quoteNumbers)) {
      putBody.put('keyword2', keywordSet.quoteNumbers);
    }
    if (!String.isBlank(keywordSet.poNumbers)) {
      putBody.put('keyword3', keywordSet.poNumbers);
    }
    putBody.put('keyword4', customerNumber);
    System.debug(putBody);
    req.setBody(JSON.serialize(putBody));

    HttpResponse res = h.send(req);
    System.debug(res.getBody());
    return res;
  }

  private static String buildFailedUploadMessage(
    HttpResponse res,
    WebDocsKeywordSet keywordSet
  ) {
    String message = 'WebDocs upload failed';
    if (!String.isBlank(keywordSet.orderNumbers)) {
      message += ' for order ' + keywordSet.orderNumbers;
    }
    if (res != null) {
      message += ' (' + res.getStatusCode() + ')';
      if (!String.isBlank(res.getBody())) {
        message += ': ' + res.getBody();
      }
    }

    return message;
  }

  private static String buildRelationshipUploadMessage(
    Integer totalRelationshipCount,
    Integer successCount,
    List<String> failureMessages
  ) {
    if (successCount <= 0) {
      return failureMessages.isEmpty()
        ? 'WebDocs upload failed.'
        : failureMessages[0];
    }

    String message =
      'Uploaded ' +
      String.valueOf(successCount) +
      ' of ' +
      String.valueOf(totalRelationshipCount) +
      ' order relationships.';
    if (!failureMessages.isEmpty()) {
      message += ' ' + failureMessages[0];
    }

    return message;
  }

  private static String normalizeStatus(String rawStatus, String fileName) {
    if (String.isBlank(rawStatus)) {
      return 'warning';
    }

    String normalizedStatus = rawStatus.trim().toLowerCase();
    if (normalizedStatus == 'success') {
      return 'success';
    }
    if (normalizedStatus == 'error') {
      return 'error';
    }

    return 'warning';
  }

  private static void applyStatus(
    WebDocsWrapper webDoc,
    String normalizedStatus
  ) {
    webDoc.webDocsStatus = normalizedStatus;
    webDoc.isSuccess = normalizedStatus == 'success';
    webDoc.isWarning = normalizedStatus == 'warning';
    webDoc.isError = normalizedStatus == 'error';
  }

  private static List<WebDocsKeywordSet> buildKeywordSets(
    String relationshipsJson,
    String legacyOrderNumbers,
    String legacyQuoteNumbers,
    String legacyPoNumbers
  ) {
    List<WebDocsKeywordSet> keywordSets = buildRelationshipKeywordSets(
      relationshipsJson
    );
    if (!keywordSets.isEmpty()) {
      return keywordSets;
    }

    return new List<WebDocsKeywordSet>{
      buildKeywordSetFromRawValues(
        legacyOrderNumbers,
        legacyQuoteNumbers,
        legacyPoNumbers
      )
    };
  }

  private static List<WebDocsKeywordSet> buildRelationshipKeywordSets(
    String relationshipsJson
  ) {
    List<WebDocsKeywordSet> keywordSets = new List<WebDocsKeywordSet>();
    if (String.isBlank(relationshipsJson)) {
      return keywordSets;
    }

    try {
      List<Object> relationshipEntries = (List<Object>) JSON.deserializeUntyped(
        relationshipsJson
      );
      for (Object relationshipEntry : relationshipEntries) {
        if (relationshipEntry == null) {
          continue;
        }

        Map<String, Object> relationship = (Map<String, Object>) relationshipEntry;
        WebDocsKeywordSet keywordSet = buildKeywordSetFromRelationship(
          relationship.containsKey('orderNumber')
            ? relationship.get('orderNumber')
            : null,
          relationship.containsKey('quoteNumbers')
            ? relationship.get('quoteNumbers')
            : relationship.get('quoteNumber'),
          relationship.containsKey('poNumbers')
            ? relationship.get('poNumbers')
            : relationship.get('poNumber')
        );
        if (!keywordSet.isEmpty()) {
          keywordSets.add(keywordSet);
        }
      }

      return keywordSets;
    } catch (Exception ex) {
      return new List<WebDocsKeywordSet>();
    }
  }

  private static WebDocsKeywordSet buildKeywordSetFromRelationship(
    Object rawOrderValue,
    Object rawQuoteValue,
    Object rawPoValue
  ) {
    List<String> orderNumbers = new List<String>();
    List<String> quoteNumbers = new List<String>();
    List<String> poNumbers = new List<String>();
    Set<String> seenOrderNumbers = new Set<String>();
    Set<String> seenQuoteNumbers = new Set<String>();
    Set<String> seenPoNumbers = new Set<String>();

    addValueContainer(rawOrderValue, orderNumbers, seenOrderNumbers);
    addValueContainer(rawQuoteValue, quoteNumbers, seenQuoteNumbers);
    addValueContainer(rawPoValue, poNumbers, seenPoNumbers);

    return buildKeywordSet(orderNumbers, quoteNumbers, poNumbers);
  }

  private static WebDocsKeywordSet buildKeywordSetFromRawValues(
    String rawOrderValues,
    String rawQuoteValues,
    String rawPoValues
  ) {
    List<String> orderNumbers = new List<String>();
    List<String> quoteNumbers = new List<String>();
    List<String> poNumbers = new List<String>();
    Set<String> seenOrderNumbers = new Set<String>();
    Set<String> seenQuoteNumbers = new Set<String>();
    Set<String> seenPoNumbers = new Set<String>();

    addTokens(rawOrderValues, orderNumbers, seenOrderNumbers);
    addTokens(rawQuoteValues, quoteNumbers, seenQuoteNumbers);
    addTokens(rawPoValues, poNumbers, seenPoNumbers);

    return buildKeywordSet(orderNumbers, quoteNumbers, poNumbers);
  }

  private static WebDocsKeywordSet buildKeywordSet(
    List<String> orderNumbers,
    List<String> quoteNumbers,
    List<String> poNumbers
  ) {
    WebDocsKeywordSet keywordSet = new WebDocsKeywordSet();
    keywordSet.folderName = orderNumbers.isEmpty() ? 'QUOTEM' : 'ORDERM';
    keywordSet.orderNumbers = String.join(orderNumbers, ';');
    keywordSet.quoteNumbers = String.join(quoteNumbers, ';');
    keywordSet.poNumbers = String.join(poNumbers, ';');
    return keywordSet;
  }

  private static void addValueContainer(
    Object rawValue,
    List<String> values,
    Set<String> seenValues
  ) {
    if (rawValue == null) {
      return;
    }

    if (rawValue instanceof String) {
      addTokens((String) rawValue, values, seenValues);
      return;
    }

    try {
      for (Object nestedValue : (List<Object>) rawValue) {
        addValueContainer(nestedValue, values, seenValues);
      }
    } catch (Exception ex) {
      addTokens(String.valueOf(rawValue), values, seenValues);
    }
  }

  private static void addTokens(
    String rawValue,
    List<String> values,
    Set<String> seenValues
  ) {
    if (String.isBlank(rawValue)) {
      return;
    }

    for (String token : rawValue.split(';')) {
      String trimmedToken = token == null ? null : token.trim();
      if (String.isBlank(trimmedToken)) {
        continue;
      }

      String normalizedToken = trimmedToken.toLowerCase();
      if (seenValues.contains(normalizedToken)) {
        continue;
      }

      seenValues.add(normalizedToken);
      values.add(trimmedToken);
    }
  }

  public class WebDocsWrapper {
    @AuraEnabled
    public Id id { get; set; }
    @AuraEnabled
    public Id contentVersionId { get; set; }
    @AuraEnabled
    public String title { get; set; }
    @AuraEnabled
    public String webDocsName { get; set; }
    @AuraEnabled
    public String webDocsStatus { get; set; }
    @AuraEnabled
    public Boolean reviseFile { get; set; }
    @AuraEnabled
    public Boolean isSuccess { get; set; }
    @AuraEnabled
    public Boolean isWarning { get; set; }
    @AuraEnabled
    public Boolean isError { get; set; }
    @AuraEnabled
    public Boolean isHidden { get; set; }
  }

  public class WebDocsUploadResult {
    @AuraEnabled
    public Id contentDocId { get; set; }
    @AuraEnabled
    public Id contentVersionId { get; set; }
    @AuraEnabled
    public String webDocsName { get; set; }
    @AuraEnabled
    public String status { get; set; }
    @AuraEnabled
    public Boolean success { get; set; }
    @AuraEnabled
    public String message { get; set; }
  }

  private class WebDocsKeywordSet {
    public String folderName { get; set; }
    public String orderNumbers { get; set; }
    public String quoteNumbers { get; set; }
    public String poNumbers { get; set; }

    public Boolean isEmpty() {
      return String.isBlank(orderNumbers) &&
        String.isBlank(quoteNumbers) &&
        String.isBlank(poNumbers);
    }
  }
}