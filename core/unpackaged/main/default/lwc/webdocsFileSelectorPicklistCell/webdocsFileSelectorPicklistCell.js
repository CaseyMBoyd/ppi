import { LightningElement, api } from "lwc";

export default class WebdocsFileSelectorPicklistCell extends LightningElement {
  @api recordId;
  @api value;
  @api options = [];
  @api label;
  @api placeholder;
  isOpen = false;
  dropdownStyle = "";

  get selectedLabel() {
    return (
      this.options.find((option) => option.value === this.value)?.label ||
      this.placeholder
    );
  }

  get selectedValueClass() {
    return this.value ? "slds-truncate" : "slds-truncate placeholder";
  }

  handleToggle() {
    this.isOpen = !this.isOpen;
    if (this.isOpen) {
      this.positionDropdown();
    }
  }

  handleFocusOut() {
    window.clearTimeout(this.closeTimeout);
    this.closeTimeout = window.setTimeout(() => {
      this.isOpen = false;
    }, 150);
  }

  handleOptionMouseDown(event) {
    event.preventDefault();
    const value = event.currentTarget.dataset.value;
    this.isOpen = false;
    this.value = value;
    this.dispatchPicklistChange(value);
  }

  positionDropdown() {
    window.requestAnimationFrame(() => {
      const trigger = this.template.querySelector(".combobox-trigger");
      if (!trigger) {
        return;
      }

      const rect = trigger.getBoundingClientRect();
      this.dropdownStyle = [
        "position: fixed",
        `top: ${rect.bottom}px`,
        `left: ${rect.left}px`,
        `width: ${rect.width}px`,
        "z-index: 10000"
      ].join("; ");
    });
  }

  dispatchPicklistChange(value) {
    this.dispatchEvent(
      new CustomEvent("picklistchange", {
        bubbles: true,
        composed: true,
        detail: {
          recordId: this.recordId,
          value
        }
      })
    );
  }
}