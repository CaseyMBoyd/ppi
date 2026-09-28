import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";

export default class WebdocsFilePreview extends NavigationMixin(
  LightningElement
) {
  @api recordId;
  @api fileName;
  handleClick(e) {
    e.preventDefault();
    this[NavigationMixin.Navigate]({
      type: "standard__namedPage",
      attributes: {
        pageName: "filePreview"
      },
      state: {
        recordIds: this.recordId,
        selectedRecordId: this.recordId
      }
    });
  }
}