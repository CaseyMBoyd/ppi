/* CRM-4420: "My Part Numbers" manager page. */
import { LightningElement, wire, track } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getSessionContext } from "commerce/contextApi";
import isFeatureEnabled from "@salesforce/apex/CustomerPartNumberController.isFeatureEnabled";
import getMappings from "@salesforce/apex/CustomerPartNumberController.getMappings";
import saveMapping from "@salesforce/apex/CustomerPartNumberController.saveMapping";
import deleteMapping from "@salesforce/apex/CustomerPartNumberController.deleteMapping";

const COLUMNS = [
    { label: "Customer Part Number", fieldName: "Customer_Part_Number__c", editable: true },
    { label: "PPI SKU", fieldName: "PPI_SKU_Input__c", editable: true },
    { label: "Status", fieldName: "Validation_Status__c" },
    { label: "Active", fieldName: "Is_Active__c", type: "boolean" },
    { type: "action", typeAttributes: { rowActions: [{ label: "Delete", name: "delete" }] } },
];

export default class CustomerPartNumberManager extends LightningElement {
    accountId;
    isEnabled = false;
    columns = COLUMNS;
    @track mappings = [];
    draftValues = [];
    wiredResult;

    // New-row form
    newPartNumber = "";
    newSku = "";

    async connectedCallback() {
        try {
            const sessionContext = await getSessionContext();
            this.accountId = sessionContext?.effectiveAccountId;
            if (this.accountId) {
                this.isEnabled = await isFeatureEnabled({ accountId: this.accountId });
            }
        } catch (e) {
            console.error(e);
        }
    }

    @wire(getMappings, { accountId: "$accountId" })
    wiredMappings(result) {
        this.wiredResult = result;
        if (result.data) {
            this.mappings = result.data;
        }
    }

    get hasMappings() {
        return this.mappings && this.mappings.length > 0;
    }

    handlePartNumberChange(e) { this.newPartNumber = e.target.value; }
    handleSkuChange(e) { this.newSku = e.target.value; }

    async handleAdd() {
        if (!this.newPartNumber || !this.newSku) {
            this.toast("Missing data", "Enter both a part number and a PPI SKU.", "warning");
            return;
        }
        try {
            await saveMapping({
                record: {
                    sobjectType: "Customer_Product_Mapping__c",
                    Account__c: this.accountId,
                    Customer_Part_Number__c: this.newPartNumber,
                    PPI_SKU_Input__c: this.newSku,
                },
            });
            this.newPartNumber = "";
            this.newSku = "";
            this.toast("Saved", "Mapping submitted and being validated.", "success");
            await refreshApex(this.wiredResult);
        } catch (e) {
            this.toast("Error", this.reduceError(e), "error");
        }
    }

    async handleSave(event) {
        const updates = event.detail.draftValues;
        try {
            for (const row of updates) {
                await saveMapping({
                    record: {
                        sobjectType: "Customer_Product_Mapping__c",
                        Id: row.Id,
                        Customer_Part_Number__c: row.Customer_Part_Number__c,
                        PPI_SKU_Input__c: row.PPI_SKU_Input__c,
                    },
                });
            }
            this.draftValues = [];
            this.toast("Saved", "Changes submitted for validation.", "success");
            await refreshApex(this.wiredResult);
        } catch (e) {
            this.toast("Error", this.reduceError(e), "error");
        }
    }

    async handleRowAction(event) {
        const { action, row } = event.detail;
        if (action.name === "delete") {
            try {
                await deleteMapping({ recordId: row.Id });
                await refreshApex(this.wiredResult);
            } catch (e) {
                this.toast("Error", this.reduceError(e), "error");
            }
        }
    }

    async handleUploadComplete() {
        await refreshApex(this.wiredResult);
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    reduceError(e) {
        return (e?.body?.message) || e?.message || "Unexpected error.";
    }
}