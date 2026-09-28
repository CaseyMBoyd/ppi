import { LightningElement, api, wire } from 'lwc';
import getFilteredImages from '@salesforce/apex/FilteredEmailImagesController.getFilteredImages';
import addToFiles from '@salesforce/apex/FilteredEmailImagesController.addToFiles';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class FilteredEmailImages extends LightningElement {

    @api recordId;

    images = [];
    wiredImagesResult;

    isPreviewOpen = false;
    previewUrl;
    previewTitle;

    @wire(getFilteredImages, { recordId: '$recordId' })
    wiredImages(result) {
        this.wiredImagesResult = result;

        console.log('LWC recordId:', this.recordId);
        console.log('LWC wire result:', result);
        console.log('LWC data:', result.data);
        console.log('LWC error:', result.error);

        const { data, error } = result;

        if (data) {
            console.log('Filtered images returned:', data);

            this.images = data.map(image => ({
                id: image.Id,
                title: image.Title,
                fileName: image.PathOnClient,
                size: this.formatFileSize(image.ContentSize),
                contentDocumentId: image.ContentDocumentId,
                previewUrl: `/sfc/servlet.shepherd/version/download/${image.Id}`
            }));
        } else if (error) {
            console.error('Filtered image error:', error);

            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );
        }
    }

    handlePreview(event) {
        const contentVersionId = event.currentTarget.dataset.id;
        const image = this.images.find(item => item.id === contentVersionId);

        if (image) {
            this.previewUrl = image.previewUrl;
            this.previewTitle = image.title;
            this.isPreviewOpen = true;
        }
    }

    closePreview() {
        this.isPreviewOpen = false;
        this.previewUrl = null;
        this.previewTitle = null;
    }

    async handleAddToFiles(event) {
        const contentDocumentId = event.currentTarget.dataset.documentid;

        try {
            await addToFiles({
                contentDocumentId: contentDocumentId,
                recordId: this.recordId
            });

            this.showToast(
                'Success',
                'Image added to Files successfully.',
                'success'
            );

            // Remove the image from the custom list after it has
            // been added to the standard Files section.
            this.images = this.images.filter(
                image => image.contentDocumentId !== contentDocumentId
            );

            await refreshApex(this.wiredImagesResult);

        } catch (error) {
            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );
        }
    }

    formatFileSize(size) {
        if (!size) {
            return '0 KB';
        }

        if (size < 1024) {
            return `${size} Bytes`;
        }

        if (size < 1024 * 1024) {
            return `${(size / 1024).toFixed(1)} KB`;
        }

        return `${(size / (1024 * 1024)).toFixed(1)} MB`;
    }

    getErrorMessage(error) {
        if (error?.body?.message) {
            return error.body.message;
        }

        if (error?.message) {
            return error.message;
        }

        return 'An unexpected error occurred.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    get hasImages() {
        return this.images.length > 0;
    }
}