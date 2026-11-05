import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import executeBatchForClaim from '@salesforce/apex/GiftAidOpportunityService.executeBatchForClaim';

export default class LinkDonationsAction extends LightningElement {
    @api recordId;

    @api invoke() {
        executeBatchForClaim({ claimId: this.recordId })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Linking in Progress',
                        message: 'Linking eligible donations to this Gift Aid Claim is in progress. Please check back shortly or review your Gift Aid report to verify the linked donations.',
                        variant: 'success'
                    })
                );
            })
            .catch((error) => {
                const errorMsg = error?.body?.message || error?.message || 'An unknown error occurred.';
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error Starting Batch',
                        message: errorMsg,
                        variant: 'error'
                    })
                );
            });
    }
}