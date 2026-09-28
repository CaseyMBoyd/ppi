import { LightningElement, wire } from 'lwc';
import getCurrentExternalAccountName from '@salesforce/apex/ExternalManagedAccountController.getCurrentExternalAccountName';
import { getSessionContext } from 'commerce/contextApi';

export default class CurrentExternalAccountName extends LightningElement {
    effectiveAccountId;
    delegatedAccounts = [];
    connectedCallback() {
        getSessionContext().then((sessionContext) => {
            this.effectiveAccountId = String(sessionContext.effectiveAccountId);
            console.log('effective',this.effectiveAccountId);
        })
    }

    @wire(getCurrentExternalAccountName, {effectiveAccountId: '$effectiveAccountId'})
    wiredDelegatedAccounts;

    get delegatedAccountName() {
        return this.wiredDelegatedAccounts.data;
    }
}