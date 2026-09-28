import { LightningElement, api, wire } from 'lwc';
import getLeadTimeGuidanceRules from '@salesforce/apex/LeadTimeMetadataControllerB2B.getLeadTimeGuidanceRules';
export default class B2bLeadTimeTooltip extends LightningElement {

    @api currentWarehouseCode;
    @api activeProductCategory;
    @api requestedQuantity = 1;

    displayTooltip = false;
    contextualLeadTimeText = '';

    cachedRulesCollection = [];
    interactionDebounceTimer;

    @wire(getLeadTimeGuidanceRules)
    wiredRules({ error, data }) {
        if (data) {
            this.cachedRulesCollection = data;
        } else if (error) {
            this.cachedRulesCollection = [];
        }
    }

    handleWarehouseMouseOver() {
        clearTimeout(this.interactionDebounceTimer);
        this.interactionDebounceTimer = setTimeout(() => {
            this.evaluateLeadTimeContent();
            this.displayTooltip = true;
        }, 300);
    }

    handleWarehouseMouseOut() {
        clearTimeout(this.interactionDebounceTimer);
        this.displayTooltip = false;
    }
    
    evaluateLeadTimeContent() {
        const defaultHardcodedMsg = 'Lead time information not available';
        const targetWarehouse = (this.currentWarehouseCode || '').toUpperCase();
        const targetCategory = (this.activeProductCategory || '').toUpperCase();
        const targetQty = Number(this.requestedQuantity);
        const exactMatchRule = this.cachedRulesCollection.find(rule => {
            return !rule.Is_Fallback__c && rule.Location_Code__c.toUpperCase() === targetWarehouse &&
                rule.Product_Category__c.toUpperCase() === targetCategory &&
                targetQty >= rule.Min_Quantity__c && targetQty <= rule.Max_Quantity__c;
        });
        if (exactMatchRule) {
            this.contextualLeadTimeText = exactMatchRule.Lead_Time_Display_Value__c;
        } else {
            const warehouseFallbackRule = this.cachedRulesCollection.find(rule =>

                rule.Is_Fallback__c === true && rule.Location_Code__c.toUpperCase() === targetWarehouse);
            this.contextualLeadTimeText = warehouseFallbackRule ? warehouseFallbackRule.Lead_Time_Display_Value__c : defaultHardcodedMsg;
        }
    }
}