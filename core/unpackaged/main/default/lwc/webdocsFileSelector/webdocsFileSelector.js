import { LightningElement, api, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getContentDocs from "@salesforce/apex/WebDocsFileSelectorController.getContentDocs";
import updateHiddenFileStatus from "@salesforce/apex/WebDocsFileSelectorController.updateHiddenFileStatus";
import uploadToWebDocs from "@salesforce/apex/WebDocsFileSelectorController.uploadToWebDocs";

export default class WebdocsFileSelector extends LightningElement {
  @api recordId;
  isUploading = false;
  showHiddenFiles = false;
  selectedWebDocsNames = new Map();

  @wire(getContentDocs, { recordId: "$recordId" })
  contentDocsWire;

  get contentDocs() {
    return (this.contentDocsWire.data || []).map((contentDoc) => {
      if (!this.selectedWebDocsNames.has(contentDoc.id)) {
        return contentDoc;
      }

      return {
        ...contentDoc,
        webDocsName: this.selectedWebDocsNames.get(contentDoc.id)
      };
    });
  }

  get visibleContentDocs() {
    return this.contentDocs.filter((contentDoc) => !contentDoc.isHidden);
  }

  get hiddenContentDocs() {
    return this.contentDocs.filter((contentDoc) => contentDoc.isHidden);
  }

  get hasHiddenFiles() {
    return this.hiddenContentDocs.length > 0;
  }

  get hiddenFilesButtonLabel() {
    const hiddenFileCount = this.hiddenContentDocs.length;
    const actionLabel = this.showHiddenFiles ? "Hide" : "Show";
    return `${actionLabel} Hidden Files (${hiddenFileCount})`;
  }

  get hiddenFilesButtonIconName() {
    return this.showHiddenFiles ? "utility:hide" : "utility:preview";
  }

  get disableUpload() {
    return this.isUploading || !this.visibleContentDocs.length;
  }

  get docTypeOptions() {
    return [
      { label: "RFQ", value: "RFQ" },
      { label: "CUSTOMER PO", value: "CUSTOMER PO" },
      { label: "EMAIL", value: "EMAIL" },
      { label: "PRINT", value: "PRINT" },
      { label: "DELIVERY", value: "DELIVERY" },
      { label: "PRICING REQUEST", value: "PRICING REQUEST" },
      { label: "SHIPPING INFO", value: "SHIPPING INFO" },
      { label: "ORDER CHANGE", value: "ORDER CHANGE" },
      { label: "OTHER", value: "OTHER" }
    ];
  }

  get columns() {
    return [
      {
        label: "File",
        fieldName: "title",
        type: "filePreview",
        typeAttributes: {
          recordId: { fieldName: "id" },
          fileName: { fieldName: "title" }
        }
      },
      {
        label: "WebDocs Name",
        type: "customPicklist",
        fieldName: "webDocsName",
        typeAttributes: {
          options: this.docTypeOptions,
          label: "WebDocs Name",
          value: { fieldName: "webDocsName" },
          placeholder: "Select WebDocs File Name",
          recordId: { fieldName: "id" }
        }
      },
      {
        label: "Status",
        fieldName: "webDocsStatus",
        type: "statusIndicator",
        typeAttributes: {
          success: { fieldName: "isSuccess" },
          warning: { fieldName: "isWarning" },
          error: { fieldName: "isError" }
        }
      },
      {
        type: "button-icon",
        fixedWidth: 48,
        typeAttributes: {
          name: "hide",
          iconName: "utility:hide",
          alternativeText: "Hide file",
          title: "Hide file",
          variant: "border-filled"
        }
      }
    ];
  }

  async handleRowAction(event) {
    if (event.detail.action.name !== "hide") {
      return;
    }

    await this.updateFileVisibility(event.detail.row, true);
  }

  async handleShowFile(event) {
    const fileId = event.currentTarget.dataset.id;
    const contentDoc = this.hiddenContentDocs.find((doc) => doc.id === fileId);

    await this.updateFileVisibility(contentDoc, false);

    if (this.hiddenContentDocs.length <= 1) {
      this.showHiddenFiles = false;
    }
  }

  handleToggleHiddenFiles() {
    this.showHiddenFiles = !this.showHiddenFiles;
  }

  handlePicklistChange(event) {
    const { recordId, value } = event.detail;
    if (!recordId) {
      return;
    }

    const selectedWebDocsNames = new Map(this.selectedWebDocsNames);
    selectedWebDocsNames.set(recordId, value);
    this.selectedWebDocsNames = selectedWebDocsNames;
  }

  async updateFileVisibility(contentDoc, isHidden) {
    if (!contentDoc?.contentVersionId) {
      this.showToast(
        "File Visibility Not Saved",
        "A selected file could not be matched to its Content Version.",
        "error"
      );
      return;
    }

    try {
      await updateHiddenFileStatus({
        contentVersionId: contentDoc.contentVersionId,
        isHidden
      });
      this.removeDraftValue(contentDoc.id);
      await refreshApex(this.contentDocsWire);
    } catch (error) {
      this.showToast(
        "File Visibility Not Saved",
        this.getErrorMessage(error),
        "error"
      );
    }
  }

  removeDraftValue(fileId) {
    if (this.selectedWebDocsNames.has(fileId)) {
      const selectedWebDocsNames = new Map(this.selectedWebDocsNames);
      selectedWebDocsNames.delete(fileId);
      this.selectedWebDocsNames = selectedWebDocsNames;
    }

    const datatable = this.template.querySelector(
      "c-webdocs-file-selector-picklist"
    );

    if (!datatable?.draftValues?.length) {
      return;
    }

    datatable.draftValues = datatable.draftValues.filter((draftValue) => {
      const rowId = draftValue.id || draftValue.Id;
      return rowId !== fileId;
    });
  }

  async handleUpload() {
    const datatable = this.template.querySelector(
      "c-webdocs-file-selector-picklist"
    );
    const draftValues = datatable?.draftValues || [];
    const uploadRequests = this.buildUploadRequests(draftValues);

    if (!uploadRequests.length) {
      this.showToast(
        "Nothing to Upload",
        "Choose a WebDocs File Name before uploading.",
        "warning"
      );
      return;
    }

    const results = [];

    this.isUploading = true;
    try {
      for (const uploadRequest of uploadRequests) {
        if (uploadRequest.errorMessage) {
          results.push({
            success: false,
            message: uploadRequest.errorMessage
          });
          continue;
        }

        results.push(
          await uploadToWebDocs({
            contentDocId: uploadRequest.contentDoc.id,
            fileName: uploadRequest.fileName,
            reviseFile: false,
            oppId: this.recordId
          })
        );
      }

      await refreshApex(this.contentDocsWire);

      if (datatable) {
        datatable.draftValues = [];
      }
      this.selectedWebDocsNames = new Map();

      this.showUploadSummary(results);
    } catch (error) {
      this.showToast("Upload Failed", this.getErrorMessage(error), "error");
    } finally {
      this.isUploading = false;
    }
  }

  buildUploadRequests(draftValues) {
    const contentDocsById = new Map(
      this.visibleContentDocs.map((contentDoc) => [contentDoc.id, contentDoc])
    );
    const uploadRequestsById = new Map();

    for (const [rowId, fileName] of this.selectedWebDocsNames.entries()) {
      const contentDoc = contentDocsById.get(rowId);
      if (!contentDoc) {
        continue;
      }

      uploadRequestsById.set(rowId, {
        contentDoc,
        fileName
      });
    }

    for (const draftValue of draftValues) {
      const rowId = draftValue.id || draftValue.Id;
      const contentDoc = contentDocsById.get(rowId);

      if (!contentDoc) {
        uploadRequestsById.set(rowId, {
          errorMessage:
            "A selected file could not be matched to the current table rows."
        });
        continue;
      }

      uploadRequestsById.set(rowId, {
        contentDoc,
        fileName: draftValue.webDocsName ?? contentDoc.webDocsName
      });
    }

    for (const contentDoc of this.visibleContentDocs) {
      if (
        !this.hasErrorStatus(contentDoc) ||
        uploadRequestsById.has(contentDoc.id)
      ) {
        continue;
      }

      uploadRequestsById.set(contentDoc.id, {
        contentDoc,
        fileName: contentDoc.webDocsName
      });
    }

    return Array.from(uploadRequestsById.values());
  }

  hasErrorStatus(contentDoc) {
    return contentDoc?.isError || contentDoc?.webDocsStatus === "error";
  }

  showUploadSummary(results) {
    const successCount = results.filter((result) => result?.success).length;
    const failureMessages = results
      .filter((result) => !result?.success)
      .map(
        (result) =>
          result?.message || "One or more files failed to upload to WebDocs."
      );

    if (!failureMessages.length) {
      this.showToast(
        "Upload Complete",
        `${successCount} file${successCount === 1 ? "" : "s"} uploaded to WebDocs.`,
        "success"
      );
      return;
    }

    if (!successCount) {
      this.showToast("Upload Failed", failureMessages[0], "error");
      return;
    }

    this.showToast(
      "Upload Partially Complete",
      `${successCount} file${
        successCount === 1 ? "" : "s"
      } uploaded. ${failureMessages[0]}`,
      "warning"
    );
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

    return "An unexpected error occurred while uploading files to WebDocs.";
  }
}