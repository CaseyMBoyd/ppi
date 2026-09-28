/* Copyright (c) 2024 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */

import { api, LightningElement, track } from 'lwc';
import hasOrderAlreadyBeenReviewed from '@salesforce/apex/CustomerSatisfactionSurveyCtrl.hasOrderAlreadyBeenReviewed';
import addCustomerSatisfaction from '@salesforce/apex/CustomerSatisfactionSurveyCtrl.addCustomerSatisfaction';

export default class CustomerSatisfactionSurvey extends LightningElement {
    @api orderNumber;

    isSatisfied;
    comments = '';
    @track isLoading = false;
    @track hasSubmitted = false;

    get thumbsUpButtonClass() {
        return `thumb-button ${this.isSatisfied ? 'selected' : ''}`;
    }

    get thumbsDownButtonClass() {
        return `thumb-button ${this.isSatisfied === false ? 'selected' : ''}`;
    }

    connectedCallback() {
        hasOrderAlreadyBeenReviewed({ orderNumber: this.orderNumber })
            .then(result => {
                this.hasSubmitted = result;
            })
            .catch(error => {
                console.error(error);
            });
    }

    setSatisfied() {
        this.isSatisfied = true;
    }

    setUnsatisfied() {
        this.isSatisfied = false;
    }

    handleCommentsChange(event) {
        this.comments = event.target.value;
    }

    handleSubmit() {
        this.isLoading = true;

        addCustomerSatisfaction({ orderNumber: this.orderNumber, isSatisfied: this.isSatisfied, comments: this.comments })
            .then(() => {
                this.hasSubmitted = true;
            })
            .catch(error => {
                console.error(error);
            });
    }
}