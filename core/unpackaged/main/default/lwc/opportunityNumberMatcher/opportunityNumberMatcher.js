import { LightningElement, api, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getRecord, updateRecord } from "lightning/uiRecordApi";

import {
  buildSourceSnapshot,
  buildSelectableOptions,
  buildRelationshipRows,
  hasRelationshipDrift as checkRelationshipDrift,
  hasSourceSnapshotDrift as checkSourceSnapshotDrift,
  normalizeValueList,
  parseStoredRelationships,
  requiresUserReview,
  serializeRelationships,
  tokenizeSemicolonValue
} from "./numberRelationshipUtils";

const FIELD_ORDER_NUMBER = "Opportunity.Order_Number__c";
const FIELD_QUOTE_NUMBER = "Opportunity.Quote_Number__c";
const FIELD_PO_NUMBER = "Opportunity.PO_Number__c";
const FIELD_RELATIONSHIPS = "Opportunity.Order_Number_Relationships__c";
const RECORD_FIELDS = [
  FIELD_ORDER_NUMBER,
  FIELD_QUOTE_NUMBER,
  FIELD_PO_NUMBER,
  FIELD_RELATIONSHIPS
];

export default class OpportunityNumberMatcher extends LightningElement {
  @api recordId;

  isLoading = true;
  isSaving = false;
  loadError = "";
  parseWarning = "";
  requiresRelationshipRefresh = false;
  autoMatchMessage = "";
  autoMatchSaved = false;
  autoMatchRequiresManualSave = false;
  hasManualChanges = false;
  lastAutoSaveSignature = "";

  orderNumberItems = [];
  quoteNumberItems = [];
  poNumberItems = [];
  rows = [];
  quoteOptions = [];
  poOptions = [];
  lastSavedSerialized = "[]";
  wiredRecordResult;

  @wire(getRecord, { recordId: "$recordId", fields: RECORD_FIELDS })
  wiredOpportunity(result) {
    this.wiredRecordResult = result;

    if (result.data) {
      this.loadError = "";
      this.initializeFromRecord(result.data);
      return;
    }

    if (result.error) {
      this.isLoading = false;
      this.loadError = this.getErrorMessage(result.error);
    }
  }

  get isBusy() {
    return this.isLoading || this.isSaving;
  }

  get hasOrderNumbers() {
    return this.orderNumberItems.length > 0;
  }

  get hasQuoteNumbers() {
    return this.quoteNumberItems.length > 0;
  }

  get hasPoNumbers() {
    return this.poNumberItems.length > 0;
  }

  get needsUserReview() {
    return (
      this.hasOrderNumbers &&
      requiresUserReview(
        this.orderNumberItems.map((item) => item.value),
        this.quoteNumberItems.map((item) => item.value),
        this.poNumberItems.map((item) => item.value)
      )
    );
  }

  get shouldAutoComplete() {
    return this.hasOrderNumbers && !this.needsUserReview;
  }

  get shouldAutoApplyMatches() {
    return this.hasOrderNumbers;
  }

  get currentSourceSnapshot() {
    return buildSourceSnapshot(
      this.orderNumberItems.map((item) => item.value),
      this.quoteNumberItems.map((item) => item.value),
      this.poNumberItems.map((item) => item.value)
    );
  }

  get currentSerializedRelationships() {
    return serializeRelationships(this.rows, this.currentSourceSnapshot);
  }

  get hasUnsavedChanges() {
    return (
      this.currentSerializedRelationships !== this.lastSavedSerialized ||
      this.requiresRelationshipRefresh
    );
  }

  get disableSave() {
    return !this.recordId || !this.hasUnsavedChanges || this.isBusy;
  }

  get disableReset() {
    return !this.recordId || this.isBusy;
  }

  get showMatcher() {
    return this.hasOrderNumbers && this.needsUserReview;
  }

  get showAutoMatchedSummary() {
    return this.shouldAutoComplete && this.rows.length > 0;
  }

  get showFooterActions() {
    return (
      this.hasOrderNumbers &&
      (this.hasManualChanges || this.autoMatchRequiresManualSave)
    );
  }

  get confirmButtonLabel() {
    return this.hasManualChanges ? "Save Changes" : "Save Matches";
  }

  get introMessage() {
    return this.needsUserReview
      ? "The matcher auto-applies row-based matches from entry order. Review the summaries below, and only expand a row if you want to edit the quote or PO lists."
      : "When there is only one logical outcome, the matcher applies it automatically without opening the review UI.";
  }

  get autoMatchHeading() {
    return this.hasUnsavedChanges ? "Proposed Matches" : "Saved Matches";
  }

  get showEmptyState() {
    return !this.isLoading && !this.loadError && !this.hasOrderNumbers;
  }

  get showRefreshNotice() {
    return this.requiresRelationshipRefresh && !this.loadError;
  }

  get statusMessage() {
    if (!this.hasOrderNumbers) {
      if (this.hasUnsavedChanges) {
        return "No order numbers remain. Save to clear the stored relationships.";
      }

      return "Add at least one order number to begin matching.";
    }

    if (this.isSaving) {
      if (this.hasManualChanges) {
        return "Saving your manual match changes.";
      }

      return "Applying the proposed matches automatically.";
    }

    if (this.hasManualChanges) {
      return "Manual changes are ready to be saved.";
    }

    if (this.autoMatchRequiresManualSave) {
      return "Automatic matching could not be saved. Review the proposed rows and save them manually.";
    }

    if (this.autoMatchSaved && !this.hasUnsavedChanges) {
      return this.needsUserReview
        ? "The proposed matches were applied automatically. Expand any row if you want to make changes."
        : "The only logical set of matches has been applied automatically.";
    }

    if (this.hasUnsavedChanges) {
      return "The proposed matches are ready to be applied automatically.";
    }

    return "Saved matches are in sync with the current order, quote, and PO numbers.";
  }

  initializeFromRecord(record) {
    const orderNumbers = tokenizeSemicolonValue(
      this.getRecordFieldValue(record, FIELD_ORDER_NUMBER)
    );
    const quoteNumbers = tokenizeSemicolonValue(
      this.getRecordFieldValue(record, FIELD_QUOTE_NUMBER)
    );
    const poNumbers = tokenizeSemicolonValue(
      this.getRecordFieldValue(record, FIELD_PO_NUMBER)
    );
    const storedRelationships = parseStoredRelationships(
      this.getRecordFieldValue(record, FIELD_RELATIONSHIPS)
    );
    const currentSourceSnapshot = buildSourceSnapshot(
      orderNumbers,
      quoteNumbers,
      poNumbers
    );
    const storedSourceSnapshot = storedRelationships.sourceSnapshot?.hasSnapshot
      ? storedRelationships.sourceSnapshot
      : currentSourceSnapshot;
    const hasRelationshipDrift = checkRelationshipDrift(
      storedRelationships.storedOrderNumbers,
      orderNumbers
    );
    const hasSourceSnapshotDrift = checkSourceSnapshotDrift(
      storedRelationships.sourceSnapshot,
      currentSourceSnapshot
    );
    const shouldRerunAutoMatch =
      storedRelationships.hasInvalidFormat ||
      hasRelationshipDrift ||
      hasSourceSnapshotDrift;

    this.orderNumberItems = this.toDisplayItems(orderNumbers, "order");
    this.quoteNumberItems = this.toDisplayItems(quoteNumbers, "quote");
    this.poNumberItems = this.toDisplayItems(poNumbers, "po");
    this.rows = buildRelationshipRows(
      orderNumbers,
      quoteNumbers,
      poNumbers,
      shouldRerunAutoMatch ? new Map() : storedRelationships.relationshipMap
    );
    this.lastSavedSerialized = serializeRelationships(
      buildRelationshipRows(
        orderNumbers,
        [],
        [],
        storedRelationships.relationshipMap
      ),
      storedSourceSnapshot
    );
    this.requiresRelationshipRefresh =
      storedRelationships.hasInvalidFormat ||
      hasRelationshipDrift ||
      hasSourceSnapshotDrift;
    this.parseWarning = storedRelationships.hasInvalidFormat
      ? "The saved relationship field was not valid JSON. Review the matches below and save to replace it with a clean value."
      : "";
    this.autoMatchSaved = false;
    this.autoMatchRequiresManualSave = false;
    this.hasManualChanges = false;
    this.autoMatchMessage = "";
    this.isLoading = false;

    this.refreshRows();
    void this.syncAutoMatchState();
  }

  toDisplayItems(values, prefix) {
    return values.map((value, index) => ({
      key: `${prefix}-${index}-${value}`,
      value
    }));
  }

  refreshRows() {
    this.quoteOptions = buildSelectableOptions(
      this.quoteNumberItems.map((item) => item.value),
      this.rows.flatMap((row) => row.quoteNumbers),
      "(saved, not in Quote Number)"
    );
    this.poOptions = buildSelectableOptions(
      this.poNumberItems.map((item) => item.value),
      this.rows.flatMap((row) => row.poNumbers),
      "(saved, not in PO Number)"
    );
    this.rows = this.rows.map((row, index) => ({
      ...row,
      key: `${index}-${row.orderNumber}`,
      isExpanded: Boolean(row.isExpanded),
      quoteNumbers: normalizeValueList(row.quoteNumbers),
      poNumbers: normalizeValueList(row.poNumbers),
      quoteSummaryText: this.buildValueSummary(
        row.quoteNumbers,
        "No quote numbers"
      ),
      poSummaryText: this.buildValueSummary(row.poNumbers, "No PO numbers"),
      toggleEditorLabel: row.isExpanded ? "Hide Editors" : "Edit Matches",
      toggleEditorIcon: row.isExpanded
        ? "utility:chevrondown"
        : "utility:chevronright"
    }));
  }

  buildValueSummary(values, emptyLabel) {
    return normalizeValueList(values).join(", ") || emptyLabel;
  }

  async syncAutoMatchState() {
    if (
      !this.recordId ||
      !this.shouldAutoApplyMatches ||
      this.hasManualChanges
    ) {
      this.autoMatchSaved = false;
      this.autoMatchRequiresManualSave = false;
      this.autoMatchMessage = "";
      return;
    }

    if (!this.hasUnsavedChanges) {
      this.autoMatchRequiresManualSave = false;
      if (!this.autoMatchSaved) {
        this.autoMatchMessage = "";
      }
      return;
    }

    const autoSaveSignature = [
      this.recordId,
      this.currentSerializedRelationships,
      this.lastSavedSerialized
    ].join(":");

    if (this.lastAutoSaveSignature === autoSaveSignature) {
      return;
    }

    this.lastAutoSaveSignature = autoSaveSignature;
    this.autoMatchRequiresManualSave = false;
    this.autoMatchMessage = "Applying the proposed matches automatically.";

    await this.saveRelationships({
      successTitle: "Matches Saved",
      successMessage: "The proposed matches were applied automatically.",
      showSuccessToast: false,
      isAutomaticSave: true
    });
  }

  async saveRelationships({
    successTitle,
    successMessage,
    showSuccessToast,
    isAutomaticSave = false
  } = {}) {
    const fields = {
      Id: this.recordId
    };
    fields[this.getFieldApiName(FIELD_RELATIONSHIPS)] =
      this.currentSerializedRelationships;

    this.isSaving = true;
    try {
      await updateRecord({ fields });

      this.lastSavedSerialized = this.currentSerializedRelationships;
      this.requiresRelationshipRefresh = false;
      this.parseWarning = "";
      this.autoMatchSaved = isAutomaticSave;
      this.autoMatchRequiresManualSave = false;
      this.hasManualChanges = false;
      this.autoMatchMessage = isAutomaticSave ? successMessage : "";

      if (showSuccessToast) {
        this.showToast(successTitle, successMessage, "success");
      }

      return true;
    } catch (error) {
      if (isAutomaticSave) {
        this.autoMatchSaved = false;
        this.autoMatchRequiresManualSave = true;
        this.autoMatchMessage =
          "Automatic matching could not be saved. Review the proposed rows and save them manually.";
      }

      this.showToast("Save Failed", this.getErrorMessage(error), "error");
      return false;
    } finally {
      this.isSaving = false;
    }
  }

  handleSelectionChange(event) {
    const index = Number(event.target.dataset.index);
    const fieldName = event.target.dataset.fieldName;

    if (!Number.isInteger(index) || !fieldName) {
      return;
    }

    this.rows = this.rows.map((row, rowIndex) =>
      rowIndex === index
        ? {
            ...row,
            [fieldName]: normalizeValueList(event.detail.value)
          }
        : row
    );

    this.autoMatchSaved = false;
    this.autoMatchRequiresManualSave = false;
    this.hasManualChanges = true;
    this.autoMatchMessage = "";
    this.refreshRows();
  }

  handleToggleEditor(event) {
    const index = Number(event.target.dataset.index);

    if (!Number.isInteger(index)) {
      return;
    }

    this.rows = this.rows.map((row, rowIndex) =>
      rowIndex === index
        ? {
            ...row,
            isExpanded: !row.isExpanded
          }
        : row
    );

    this.refreshRows();
  }

  handleReset() {
    if (this.wiredRecordResult?.data) {
      this.initializeFromRecord(this.wiredRecordResult.data);
    }
  }

  async handleSave() {
    await this.saveRelationships({
      successTitle: "Relationships Saved",
      successMessage: this.hasManualChanges
        ? "Your manual match changes were saved."
        : "The proposed matches were saved.",
      showSuccessToast: true
    });
  }

  getFieldApiName(qualifiedFieldName) {
    return qualifiedFieldName.split(".").pop();
  }

  getRecordFieldValue(record, qualifiedFieldName) {
    const fieldApiName = this.getFieldApiName(qualifiedFieldName);
    return record?.fields?.[fieldApiName]?.value || "";
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }

  getErrorMessage(error) {
    if (error?.body?.message) {
      return error.body.message;
    }

    if (
      Array.isArray(error?.body) &&
      error.body.length &&
      error.body[0]?.message
    ) {
      return error.body[0].message;
    }

    return "An unexpected error occurred.";
  }
}