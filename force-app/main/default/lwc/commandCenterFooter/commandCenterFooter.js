import { LightningElement } from 'lwc';

export default class CommandCenterFooter extends LightningElement {
    get currentYear() {
        return new Date().getFullYear();
    }
}
