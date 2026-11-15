import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue, getRecordNotifyChange, deleteRecord } from 'lightning/uiRecordApi';
import { getRelatedListRecords } from 'lightning/uiRelatedListApi';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import { refreshApex } from '@salesforce/apex';

// Import our custom apex metadata reader
import getFieldSetFields from '@salesforce/apex/GiftAidFieldSetController.getFieldSetFields';
import getRecordAccess from '@salesforce/apex/GiftAidCoveragePeriodController.getRecordAccess';

// Contact schema imports
import CONTACT_OBJECT from '@salesforce/schema/Contact';
import STATUS_FIELD from '@salesforce/schema/Contact.Gift_Aid_Status__c';
import CANCELLATION_DATE_FIELD from '@salesforce/schema/Contact.Gift_Aid_Cancellation_Date__c';
import CANCELLATION_REASON_FIELD from '@salesforce/schema/Contact.Gift_Aid_Cancellation_Reason__c';
import CLAIMABLE_ADDRESS_FIELD from '@salesforce/schema/Contact.GiftAidClaimableAddress__c';
import ADDRESS_GONE_AWAY_DATE_FIELD from '@salesforce/schema/Contact.AddressGoneAwayDate__c';

// Gift Aid Coverage Period schema imports
import PERIOD_OBJECT from '@salesforce/schema/GiftAidCoveragePeriod__c';
import PERIOD_NAME_FIELD from '@salesforce/schema/GiftAidCoveragePeriod__c.Name';
import PERIOD_CONTACT_FIELD from '@salesforce/schema/GiftAidCoveragePeriod__c.Contact__c';
import PERIOD_START_DATE_FIELD from '@salesforce/schema/GiftAidCoveragePeriod__c.StartDate__c';
import PERIOD_END_DATE_FIELD from '@salesforce/schema/GiftAidCoveragePeriod__c.EndDate__c';
import PERIOD_DECLARATION_DATE_FIELD from '@salesforce/schema/GiftAidCoveragePeriod__c.DeclarationDate__c';
import PERIOD_SOURCE_FIELD from '@salesforce/schema/GiftAidCoveragePeriod__c.Source__c';
import PERIOD_END_REASON_FIELD from '@salesforce/schema/GiftAidCoveragePeriod__c.EndReason__c';
import PERIOD_ACTIVE_FIELD from '@salesforce/schema/GiftAidCoveragePeriod__c.ActiveFormula__c';
import PERIOD_ADDRESS_LINE1_FIELD from '@salesforce/schema/GiftAidCoveragePeriod__c.AddressLine1__c';
import PERIOD_ADDRESS_CITY_FIELD from '@salesforce/schema/GiftAidCoveragePeriod__c.AddressCity__c';
import PERIOD_ADDRESS_POSTCODE_FIELD from '@salesforce/schema/GiftAidCoveragePeriod__c.AddressPostCode__c';

// Child relationship name of GiftAidCoveragePeriod__c.Contact__c (not importable from @salesforce/schema)
const PERIODS_RELATED_LIST = 'Gift_Aid_Coverage_Periods__r';

// Page size for the Periods tab; beyond this a "View All" link opens the standard related list
const PERIODS_PAGE_SIZE = 100;

// Contact fields read by the card. Optional, so a user without read access to one still sees the card.
const CONTACT_FIELDS = [STATUS_FIELD, CANCELLATION_DATE_FIELD, CANCELLATION_REASON_FIELD];

// Fields displayed on each period tile (optional, so missing field access shows "—" rather than failing)
const PERIOD_FIELDS = [
    PERIOD_NAME_FIELD,
    PERIOD_START_DATE_FIELD,
    PERIOD_END_DATE_FIELD,
    PERIOD_DECLARATION_DATE_FIELD,
    PERIOD_SOURCE_FIELD,
    PERIOD_END_REASON_FIELD,
    PERIOD_ACTIVE_FIELD
];

// Layout of the New/Edit period modal, filled left-to-right in a two-column grid.
// A null field is a blank spacer cell (only rendered on two-column screen widths).
const PERIOD_FORM_LAYOUT = [
    PERIOD_DECLARATION_DATE_FIELD, PERIOD_SOURCE_FIELD,
    PERIOD_START_DATE_FIELD,       PERIOD_END_DATE_FIELD,
    null,                          PERIOD_END_REASON_FIELD,
    PERIOD_ADDRESS_LINE1_FIELD,    PERIOD_ADDRESS_CITY_FIELD,
    PERIOD_ADDRESS_POSTCODE_FIELD
];
const FIELD_CELL_CLASS = 'slds-col slds-size_1-of-1 slds-medium-size_1-of-2';
const SPACER_CELL_CLASS = 'slds-col slds-medium-size_1-of-2 slds-show_medium';

// Fail-closed defaults used until (or if) permissions can be determined
const NO_RECORD_ACCESS = { contactEditable: false, editable: new Set(), deletable: new Set(), checkedPeriodIds: new Set() };

// Visible reasons shown next to (or inside the label of) a disabled control
const NO_PERMISSION_REASON = "you don't have permission";
const CHECK_FAILED_REASON = "permissions couldn't be checked";

const toFieldPath = field => `${field.objectApiName}.${field.fieldApiName}`;

// Server-side sort for the Periods tab: active first, then newest start date first.
// Syntax ('-' prefix = descending, object-qualified field) verified against the UI API.
const PERIOD_SORT_FIELDS = [PERIOD_ACTIVE_FIELD, PERIOD_START_DATE_FIELD];

// UI API displayValue is already locale-formatted (dates, picklist labels); fall back to the raw value
const display = (record, field) => {
    const fieldData = record.fields[field.fieldApiName];
    if (!fieldData) return '—';
    return fieldData.displayValue ?? fieldData.value ?? '—';
};

const rawValue = (record, field) => record.fields[field.fieldApiName]?.value;

// optionalFields omits fields the user can't read; distinguish "absent" from "empty"
const hasField = (record, field) => Boolean(record?.fields && field.fieldApiName in record.fields);

export default class GiftAidCard extends NavigationMixin(LightningElement) {
    @api recordId;
    @api fieldSetName = '';
    @api showAddressInfo = false;
    @api showPeriodsTab = false;

    @track fieldsArray = [];
    @track isModalOpen = false;

    // Track user input values interactively to ensure form popup loads and updates dynamically
    @track selectedDate = '';
    @track selectedReason = '';

    periodRows = [];
    hasMorePeriods = false;
    wiredPeriodsResult;
    recordAccess = NO_RECORD_ACCESS;
    accessRequestId = 0;
    accessLoaded = false;          // the latest record-access check has finished (success or failure)
    accessCheckFailed = false;
    contactObjectInfo;
    contactObjectInfoFailed = false;
    periodObjectInfo;
    periodObjectInfoFailed = false;
    periodSortBy = [];
    isPeriodModalOpen = false;
    isSavingPeriod = false;
    editingPeriodId;

    contactObjectApi = CONTACT_OBJECT.objectApiName;
    periodObjectApi = PERIOD_OBJECT.objectApiName;
    periodContactFieldApi = PERIOD_CONTACT_FIELD.fieldApiName;
    cancelDateFieldApi = CANCELLATION_DATE_FIELD.fieldApiName;
    cancelReasonFieldApi = CANCELLATION_REASON_FIELD.fieldApiName;
    claimableAddressFieldApi = CLAIMABLE_ADDRESS_FIELD.fieldApiName;
    addressGoneAwayDateFieldApi = ADDRESS_GONE_AWAY_DATE_FIELD.fieldApiName;

    // 1. Fetch Field API Names and completely HIDE cancellation items from Card view display
    @wire(getFieldSetFields, { fieldSetName: '$fieldSetName' })
    wiredFields({ error, data }) {
        if (data) {
            const dateFieldLower = this.cancelDateFieldApi.toLowerCase();
            const reasonFieldLower = this.cancelReasonFieldApi.toLowerCase();

            // Case-insensitive filtering to ensure strict removal from card layout view
            this.fieldsArray = data.filter(field => {
                const lowerField = field.toLowerCase();
                return lowerField !== dateFieldLower && lowerField !== reasonFieldLower;
            });
        } else if (error) {
            this.showToast('Error', 'Error loading Field Set definitions: ' + this.reduceError(error), 'error');
        }
    }

    // Load record-level access as soon as the record is known, so Cancel Gift Aid is gated
    // even when the Periods tab is switched off. It is re-checked whenever the periods reload.
    connectedCallback() {
        if (this.recordId) {
            this.loadRecordAccess();
        }
    }

    // 2. Track Contact status reactively for the status badge
    @wire(getRecord, { recordId: '$recordId', optionalFields: CONTACT_FIELDS })
    contact;

    // 3. Coverage periods for the "Periods" tab (only wired when the tab is enabled, and only once
    //    object info is known so the server-side sort uses fields the user can actually read)
    @wire(getRelatedListRecords, {
        parentRecordId: '$periodsParentId',
        relatedListId: PERIODS_RELATED_LIST,
        optionalFields: PERIOD_FIELDS.map(toFieldPath),
        sortBy: '$periodSortBy',
        pageSize: PERIODS_PAGE_SIZE
    })
    wiredPeriods(result) {
        this.wiredPeriodsResult = result;
        const { data, error } = result;
        if (data) {
            this.hasMorePeriods = Boolean(data.nextPageToken);
            // Order comes from the server (sortBy), so it is correct across pages, not just this one
            this.periodRows = data.records.map(record => {
                const name = display(record, PERIOD_NAME_FIELD);
                // No read access to Active → show no badge rather than a misleading "Ended"
                const activeKnown = hasField(record, PERIOD_ACTIVE_FIELD);
                const isActive = rawValue(record, PERIOD_ACTIVE_FIELD) === true;
                return {
                    id: record.id,
                    // Real URL so the link can be opened in a new tab; normal clicks use NavigationMixin
                    recordUrl: `/lightning/r/${PERIOD_OBJECT.objectApiName}/${record.id}/view`,
                    name,
                    startDate: display(record, PERIOD_START_DATE_FIELD),
                    endDate: display(record, PERIOD_END_DATE_FIELD),
                    declarationDate: display(record, PERIOD_DECLARATION_DATE_FIELD),
                    source: display(record, PERIOD_SOURCE_FIELD),
                    endReason: rawValue(record, PERIOD_END_REASON_FIELD) ? display(record, PERIOD_END_REASON_FIELD) : null,
                    statusLabel: activeKnown ? (isActive ? 'Active' : 'Ended') : null,
                    statusClass: isActive ? 'slds-theme_success' : '',
                    actionsLabel: `Actions for ${name}`
                };
            });
            // Re-check record access for the loaded periods, so sharing changes are picked up
            this.loadRecordAccess();
        } else if (error) {
            this.periodRows = [];
            this.hasMorePeriods = false;
            this.showToast('Error', 'Error loading Gift Aid coverage periods: ' + this.reduceError(error), 'error');
        }
    }

    // 4. Object- and field-level permissions (no Apex needed; cached and kept fresh by LDS).
    //    On error, controls stay disabled and the user is told why.
    @wire(getObjectInfo, { objectApiName: CONTACT_OBJECT })
    wiredContactObjectInfo({ data, error }) {
        if (data) {
            this.contactObjectInfo = data;
            this.contactObjectInfoFailed = false;
        } else if (error) {
            this.contactObjectInfo = undefined;
            this.contactObjectInfoFailed = true;
            this.showToast('Error', 'Could not check Contact permissions: ' + this.reduceError(error), 'error');
        }
    }

    @wire(getObjectInfo, { objectApiName: PERIOD_OBJECT })
    wiredPeriodObjectInfo({ data, error }) {
        if (data) {
            this.periodObjectInfo = data;
            this.periodObjectInfoFailed = false;
            // Only sort by fields the user can read (object info omits inaccessible fields)
            this.periodSortBy = PERIOD_SORT_FIELDS
                .filter(field => field.fieldApiName in (data.fields || {}))
                .map(field => `-${toFieldPath(field)}`);
        } else if (error) {
            this.periodObjectInfo = undefined;
            this.periodObjectInfoFailed = true;
            this.periodSortBy = [];
            this.showToast('Error', 'Could not check Gift Aid Coverage Period permissions: ' + this.reduceError(error), 'error');
        }
    }

    // 5. Record-level access (Contact edit + each period's edit/delete), which no wire adapter exposes.
    //    Called imperatively and uncached; fails closed (all controls disabled) on error.
    async loadRecordAccess() {
        const requestId = ++this.accessRequestId;
        const periodIds = this.periodRows.map(row => row.id);
        try {
            const result = await getRecordAccess({ contactId: this.recordId, periodIds });
            if (requestId !== this.accessRequestId) return; // a newer request superseded this one
            this.accessCheckFailed = false;
            this.recordAccess = {
                contactEditable: result.contactEditable === true,
                editable: new Set(result.editablePeriodIds || []),
                deletable: new Set(result.deletablePeriodIds || []),
                checkedPeriodIds: new Set(periodIds)
            };
        } catch (error) {
            if (requestId !== this.accessRequestId) return;
            this.accessCheckFailed = true;
            this.recordAccess = { ...NO_RECORD_ACCESS, checkedPeriodIds: new Set(periodIds) };
            this.showToast('Error', 'Could not check Gift Aid record access: ' + this.reduceError(error), 'error');
        }
        this.accessLoaded = true;
    }

    // A field is writable if the user has create (new) or edit (existing) field-level access
    static isFieldWritable(objectInfo, field, isNew) {
        const fieldInfo = objectInfo?.fields?.[field.fieldApiName];
        return Boolean(fieldInfo && (isNew ? fieldInfo.createable : fieldInfo.updateable));
    }

    // Visible reason for a disabled control: distinguish "no permission" from "couldn't check"
    disabledReason(objectInfoFailed) {
        return objectInfoFailed || this.accessCheckFailed ? CHECK_FAILED_REASON : NO_PERMISSION_REASON;
    }

    // --- Loading state: until the checks finish, controls are disabled but no reason is shown ---
    get contactPermissionsReady() {
        return this.accessLoaded && Boolean(this.contactObjectInfo || this.contactObjectInfoFailed);
    }

    get periodObjectInfoReady() {
        return Boolean(this.periodObjectInfo || this.periodObjectInfoFailed);
    }

    get periodPermissionsReady() {
        return this.accessLoaded && this.periodObjectInfoReady;
    }

    // Record access for a period is only known once a check that included its Id has finished
    isPeriodAccessReady(periodId) {
        return this.periodPermissionsReady && Boolean(this.recordAccess.checkedPeriodIds?.has(periodId));
    }

    // --- Cancel Gift Aid: Contact edit + edit access to the record + FLS on both cancellation fields ---
    get canCancelGiftAid() {
        const objectInfo = this.contactObjectInfo;
        return objectInfo?.updateable === true
            && this.recordAccess.contactEditable
            && GiftAidCard.isFieldWritable(objectInfo, CANCELLATION_DATE_FIELD, false)
            && GiftAidCard.isFieldWritable(objectInfo, CANCELLATION_REASON_FIELD, false);
    }

    get isCancelGiftAidDisabled() {
        return !this.canCancelGiftAid;
    }

    // The menu button stays focusable; a disabled item carries its reason in its (read-aloud) label
    get cancelGiftAidLabel() {
        if (this.canCancelGiftAid || !this.contactPermissionsReady) return 'Cancel Gift Aid';
        return `Cancel Gift Aid (${this.disabledReason(this.contactObjectInfoFailed)})`;
    }

    // --- Coverage Periods ---
    isPeriodFieldWritable(field, isNew) {
        return GiftAidCard.isFieldWritable(this.periodObjectInfo, field, isNew);
    }

    get canCreatePeriod() {
        return this.periodObjectInfo?.createable === true
            && this.recordAccess.contactEditable
            && this.isPeriodFieldWritable(PERIOD_CONTACT_FIELD, true);
    }

    get isNewPeriodDisabled() {
        return !this.canCreatePeriod;
    }

    // Visible helper text under the New button (disabled buttons can't be focused, so a title isn't enough)
    get newPeriodHint() {
        if (this.canCreatePeriod || !this.periodPermissionsReady) return null;
        return `You can't add coverage periods: ${this.disabledReason(this.periodObjectInfoFailed)}.`;
    }

    // Can the user edit at least one field in the modal (otherwise Edit is pointless)
    get hasUpdateableFormField() {
        return PERIOD_FORM_LAYOUT.some(field => field && this.isPeriodFieldWritable(field, false));
    }

    get periods() {
        const canUpdateObject = this.periodObjectInfo?.updateable === true && this.hasUpdateableFormField;
        const canDeleteObject = this.periodObjectInfo?.deletable === true;
        const reason = this.disabledReason(this.periodObjectInfoFailed);

        return this.periodRows.map(row => {
            const ready = this.isPeriodAccessReady(row.id);
            const canEdit = ready && canUpdateObject && this.recordAccess.editable.has(row.id);
            const canDelete = ready && canDeleteObject && this.recordAccess.deletable.has(row.id);
            return {
                ...row,
                // While checking: menu disabled, no reason. Once known: menu stays focusable and
                // disabled items say why in their label, which screen readers announce.
                actionsDisabled: !ready,
                editDisabled: !canEdit,
                deleteDisabled: !canDelete,
                editLabel: !ready || canEdit ? 'Edit' : `Edit (${reason})`,
                deleteLabel: !ready || canDelete ? 'Delete' : `Delete (${reason})`
            };
        });
    }

    handlePeriodLinkClick(event) {
        event.preventDefault();
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: event.currentTarget.dataset.id,
                objectApiName: PERIOD_OBJECT.objectApiName,
                actionName: 'view'
            }
        });
    }

    handleViewAllPeriods() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordRelationshipPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: CONTACT_OBJECT.objectApiName,
                relationshipApiName: PERIODS_RELATED_LIST,
                actionName: 'view'
            }
        });
    }

    // Modal layout cells; fields the user cannot write (field-level security) are shown disabled
    get periodFormFields() {
        const isNew = this.isNewPeriod;
        return PERIOD_FORM_LAYOUT.map((field, index) => {
            if (!field) {
                return { key: `spacer-${index}`, field: null, disabled: true, cellClass: SPACER_CELL_CLASS };
            }
            return {
                key: field.fieldApiName,
                field: field.fieldApiName,
                disabled: !this.isPeriodFieldWritable(field, isNew),
                cellClass: FIELD_CELL_CLASS
            };
        });
    }

    get isNewPeriod() {
        return !this.editingPeriodId;
    }

    get periodModalTitle() {
        return this.isNewPeriod ? 'New Gift Aid Coverage Period' : 'Edit Gift Aid Coverage Period';
    }

    handleNewPeriod() {
        if (!this.canCreatePeriod) return;
        this.editingPeriodId = undefined;
        this.isSavingPeriod = false;
        this.isPeriodModalOpen = true;
    }

    handlePeriodAction(event) {
        const { id, name } = event.currentTarget.dataset;
        const period = this.periods.find(row => row.id === id);
        if (!period) return;

        if (event.detail.value === 'edit' && !period.editDisabled) {
            this.editingPeriodId = id;
            this.isSavingPeriod = false;
            this.isPeriodModalOpen = true;
        } else if (event.detail.value === 'delete' && !period.deleteDisabled) {
            this.deletePeriod(id, name);
        }
    }

    async deletePeriod(periodId, periodName) {
        const confirmed = await LightningConfirm.open({
            message: `Are you sure you want to delete ${periodName}?`,
            label: 'Delete Gift Aid Coverage Period',
            theme: 'warning'
        });
        if (!confirmed) return;

        try {
            await deleteRecord(periodId);
            this.showToast('Success', `${periodName} was deleted.`, 'success');
            await this.refreshAll();
        } catch (error) {
            this.showToast('Error deleting record', this.reduceError(error), 'error');
        }
    }

    closePeriodModal() {
        this.isPeriodModalOpen = false;
        this.editingPeriodId = undefined;
    }

    handlePeriodSubmit() {
        this.isSavingPeriod = true;
    }

    async handlePeriodSuccess() {
        const wasNew = this.isNewPeriod;
        this.closePeriodModal();
        this.showToast('Success', wasNew ? 'Gift Aid Coverage Period created.' : 'Gift Aid Coverage Period saved.', 'success');
        await this.refreshAll();
    }

    handlePeriodError() {
        // Errors are shown inside the modal by lightning-messages; allow the user to retry
        this.isSavingPeriod = false;
    }

    // Refresh everything after a change made from the card: period and cancellation flows can update
    // the Contact (status), end periods, and change what the user may do next.
    async refreshAll() {
        await getRecordNotifyChange([{ recordId: this.recordId }]);
        if (this.wiredPeriodsResult) {
            await refreshApex(this.wiredPeriodsResult);
        }
        // wiredPeriods only re-runs (and re-checks access) when the data actually changed,
        // so re-check explicitly to be sure.
        await this.loadRecordAccess();
    }

    get contactErrorMessage() {
        return this.reduceError(this.contact?.error);
    }

    get hasMorePeriodsSuffix() {
        return this.hasMorePeriods ? '+' : '';
    }

    // Periods load only when the tab is on and object info has arrived (so sortBy is final;
    // avoids fetching twice). If object info failed, they still load, unsorted.
    get periodsParentId() {
        return this.showPeriodsTab && this.periodObjectInfoReady ? this.recordId : undefined;
    }

    get giftAidStatus() {
        return getFieldValue(this.contact.data, STATUS_FIELD);
    }

    // No read access to the status field → hide the badge rather than show a misleading "No Status"
    get showStatusBadge() {
        return hasField(this.contact?.data, STATUS_FIELD);
    }

    get giftAidStatusLabel() {
        return this.giftAidStatus || 'No Status';
    }

    get isLoading() {
        return !this.contact?.data && !this.contact?.error;
    }

    get hasFields() {
        return this.fieldsArray.length > 0;
    }

    get showNoFieldsMessage() {
        return !this.hasFields && !this.showAddressInfo;
    }

    get hasPeriods() {
        return this.periodRows.length > 0;
    }

    get periodsTabLabel() {
        return `Periods (${this.periodRows.length}${this.hasMorePeriodsSuffix})`;
    }

    get statusBadgeClass() {
        const status = this.giftAidStatus ? this.giftAidStatus.trim() : '';

        if (status === 'Active') return 'slds-theme_success';
        if (status === 'Cancelled') return 'slds-theme_error';
        if (status === 'Former') return 'slds-theme_warning';
        return '';
    }

    // Button stays disabled until at least one actionable tracking item holds data
    get isButtonDisabled() {
        return !this.selectedDate && !this.selectedReason;
    }

    handleMenuSelect(event) {
        if (event.detail.value === 'cancel_gift_aid' && this.canCancelGiftAid) {
            this.openCancelModal();
        }
    }

    openCancelModal() {
        // Fallback calculation logic for date context defaults
        const today = new Date();
        const todayStr = today.toISOString().split('T')[0];

        const existingDate = getFieldValue(this.contact?.data, CANCELLATION_DATE_FIELD);
        const existingReason = getFieldValue(this.contact?.data, CANCELLATION_REASON_FIELD);

        this.selectedDate = existingDate || todayStr;
        this.selectedReason = existingReason || '';
        this.isModalOpen = true;
    }

    handleConfirmCancel() {
        const form = this.template.querySelector('lightning-record-edit-form.cancel-form');
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

        // Refresh the contact (status badge), the coverage periods (which automation may have ended) and access
        await this.refreshAll();
    }

    handleError(event) {
        this.showToast('Error updating record', event.detail.detail, 'error');
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map(e => e.message).join(', ');
        }
        return error?.body?.message || error?.message || 'Unknown error';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
