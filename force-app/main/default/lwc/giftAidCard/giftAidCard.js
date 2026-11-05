import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue, getRecordNotifyChange } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Import our custom apex metadata reader
import getFieldSetFields from '@salesforce/apex/GiftAidFieldSetController.getFieldSetFields';

// Standard schema imports
import STATUS_FIELD from '@salesforce/schema/Contact.Gift_Aid_Status__c';
import CANCELLATION_DATE_FIELD from '@salesforce/schema/Contact.Gift_Aid_Cancellation_Date__c';
import CANCELLATION_REASON_FIELD from '@salesforce/schema/Contact.Gift_Aid_Cancellation_Reason__c';

export default class GiftAidCard extends LightningElement {
    @api recordId;
    @api fieldSetName = ''; 

    @track fieldsArray = [];
    @track isModalOpen = false;

    // Track user input values interactively to ensure form popup loads and updates dynamically
    @track selectedDate = '';
    @track selectedReason = '';

    cancelDateFieldApi = CANCELLATION_DATE_FIELD.fieldApiName;
    cancelReasonFieldApi = CANCELLATION_REASON_FIELD.fieldApiName;

    // 1. Fetch Field API Names and completely HIDE cancellation items from Card view display
    @wire(getFieldSetFields, { fieldSetName: '$fieldSetName' })
    wiredFields({ error, data }) {
        if (data) {
            const dateFieldLower = this.cancelDateFieldApi.toLowerCase();
            const reasonFieldLower = this.cancelReasonFieldApi.toLowerCase();

            // FIXED: Using case-insensitive filtering to ensure strict removal from card layout view
            this.fieldsArray = data.filter(field => {
                const lowerField = field.toLowerCase();
                return lowerField !== dateFieldLower && lowerField !== reasonFieldLower;
            });
        } else if (error) {
            this.showToast('Error', 'Error loading Field Set definitions: ' + error.body.message, 'error');
        }
    }

    // 2. Track Contact status reactively for UI pill
    @wire(getRecord, { recordId: '$recordId', fields: [STATUS_FIELD, CANCELLATION_DATE_FIELD, CANCELLATION_REASON_FIELD] })
    contact;

    get giftAidStatus() { 
        return getFieldValue(this.contact.data, STATUS_FIELD); 
    }

    get isLoading() {
        return !this.contact?.data && this.fieldsArray.length === 0;
    }

    get statusPillClass() {
        const baseClass = 'slds-badge custom-pill-small';
        const status = this.giftAidStatus ? this.giftAidStatus.trim() : '';

        if (status === 'Active') return `${baseClass} slds-theme_success`;
        if (status === 'Cancelled') return `${baseClass} custom-pill-cancelled`;
        if (status === 'Former') return `${baseClass} custom-pill-former`;
        return `${baseClass} slds-theme_light`;
    }

    // Button stays disabled until at least one actionable tracking item holds data
    get isButtonDisabled() {
        return !this.selectedDate && !this.selectedReason;
    }

    handleMenuSelect(event) {
        if (event.detail.value === 'cancel_gift_aid') {
            this.openCancelModal();
        }
    }

    openCancelModal() {
        // Fallback calculation logic for date context defaults
        const today = new Date();
        const todayStr = today.toISOString().split('T')[0];
        
        const existingDate = getFieldValue(this.contact?.data, CANCELLATION_DATE_FIELD);
        const existingReason = getFieldValue(this.contact?.data, CANCELLATION_REASON_FIELD);
        
        // FIXED: Explicitly assigning tracked variables directly to display properties instantly
        this.selectedDate = existingDate || todayStr;
        this.selectedReason = existingReason || '';
        this.isModalOpen = true;
    }

    handleConfirmCancel() {
        const form = this.template.querySelector('lightning-record-edit-form');
        if (form) {
            form.submit();
        }
    }

    closeCancelModal() {
        this.isModalOpen = false;
    }

    // Tracks user changes inside modal input tags instantly to allow validation recheck
    handleFieldChange(event) {
        const fieldName = event.target.fieldName;
        const fieldValue = event.target.value;

        if (fieldName === this.cancelDateFieldApi) {
            this.selectedDate = fieldValue;
        } else if (fieldName === this.cancelReasonFieldApi) {
            this.selectedReason = fieldValue;
        }
    }

    async handleSuccess() {
        this.showToast('Success', 'Gift Aid has been successfully updated.', 'success');
        this.isModalOpen = false;
        
        // Tells data engine layer that layout parameters have shifted, triggering immediate top pill recalculation
        await getRecordNotifyChange([{ recordId: this.recordId }]);
    }

    handleError(event) {
        this.showToast('Error updating record', event.detail.detail, 'error');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}