import { LightningElement,api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getLatestPdf from '@salesforce/apex/EmailPdfPreviewController.getLatestPdf';

export default class EmailPdfPreview extends NavigationMixin(LightningElement){

    @api recordId;
    pdf;
    status;
    isLoading=true;
    pollingInterval;

    connectedCallback(){
        this.loadPdf();
    }

    loadPdf(){

        getLatestPdf({
            recordId:this.recordId
        })
        .then(data=>{

            this.pdf=data;
            this.status=data.status;
            this.isLoading=false;

            if(this.status==='PROCESSING'){
                this.startPolling();
            }else{
                this.stopPolling();
            }

        })
        .catch(()=>{

            this.status='NO_FILE';
            this.isLoading=false;
            this.stopPolling();

        });
    }


    refreshPdf(){

        this.isLoading=true;

        this.loadPdf();

    }


    startPolling(){

        if(this.pollingInterval){
            return;
        }

        this.pollingInterval=setInterval(()=>{

            this.loadPdf();

        },3000);
    }


    stopPolling(){

        if(this.pollingInterval){

            clearInterval(this.pollingInterval);

            this.pollingInterval=null;
        }
    }


    get hasPdf(){
        return this.status==='COMPLETED';
    }


    get showProcessing(){
        return this.status==='PROCESSING';
    }


    get showEmpty(){
        return this.status==='NO_FILE';
    }


    get iframeSrc(){
        return this.pdf ? this.pdf.previewUrl:null;
    }


    disconnectedCallback(){

        this.stopPolling();

    }


    openPreview(){

        this[NavigationMixin.Navigate]({

            type:'standard__namedPage',

            attributes:{
                pageName:'filePreview'
            },

            state:{
                selectedRecordId:this.pdf.contentDocumentId,
                recordIds:this.pdf.contentDocumentId
            }
        });
    }
}