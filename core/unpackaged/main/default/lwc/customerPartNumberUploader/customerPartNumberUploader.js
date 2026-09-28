/* CRM-4420: CSV uploader sub-component for Customer Part Numbers. */
import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import processCsvUpload from "@salesforce/apex/CustomerPartNumberController.processCsvUpload";

export default class CustomerPartNumberUploader extends LightningElement {
    @api accountId;
    isLoading = false;

    get acceptedFormats() {
        return [".csv"];
    }

    handleDownloadTemplate() {
        const csv = "Customer_Part_Number,PPI_Part_Number\nEXAMPLE-001,C5-35TE-36SB\n";
        const link = document.createElement("a");
        link.href = "data:text/csv;charset=utf-8," + encodeURIComponent(csv);
        link.download = "CustomerPartNumbers_Template.csv";
        link.click();
    }

    async handleFileChange(event) {
        const file = event.target.files?.[0];
        if (!file) {
            return;
        }
        this.isLoading = true;
        try {
            const base64 = await this.readAsBase64(file);
            await processCsvUpload({ csvBase64: base64, accountId: this.accountId });
            this.dispatchEvent(new ShowToastEvent({
                title: "Upload Submitted",
                message: "Your file is being processed in the background. " +
                         "Records will be available in a few minutes.",
                variant: "info",
            }));
            this.dispatchEvent(new CustomEvent("uploadcomplete"));
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({
                title: "Upload Failed",
                message: this.reduceError(e),
                variant: "error",
            }));
        } finally {
            this.isLoading = false;
            // reset input so the same file can be re-selected
            const input = this.template.querySelector("input[type=file]");
            if (input) {
                input.value = null;
            }
        }
    }

    readAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve(reader.result.split(",")[1]);
            reader.onerror = () => reject(new Error("File read failed"));
            reader.readAsDataURL(file);
        });
    }

    reduceError(e) {
        return (e?.body?.message) || e?.message || "Unexpected error during upload.";
    }
}