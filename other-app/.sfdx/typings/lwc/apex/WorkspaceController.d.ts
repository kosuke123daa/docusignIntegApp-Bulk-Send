declare module "@salesforce/apex/WorkspaceController.createWorkspace" {
  export default function createWorkspace(param: {opportunityId: any, workspaceName: any}): Promise<any>;
}
declare module "@salesforce/apex/WorkspaceController.getWorkspaceInfo" {
  export default function getWorkspaceInfo(param: {workspaceId: any}): Promise<any>;
}
declare module "@salesforce/apex/WorkspaceController.getSavedWorkspaceId" {
  export default function getSavedWorkspaceId(param: {opportunityId: any}): Promise<any>;
}
declare module "@salesforce/apex/WorkspaceController.getOpportunityFiles" {
  export default function getOpportunityFiles(param: {opportunityId: any}): Promise<any>;
}
declare module "@salesforce/apex/WorkspaceController.uploadDocument" {
  export default function uploadDocument(param: {workspaceId: any, contentDocumentId: any}): Promise<any>;
}
declare module "@salesforce/apex/WorkspaceController.getWorkspaceDocuments" {
  export default function getWorkspaceDocuments(param: {workspaceId: any}): Promise<any>;
}
declare module "@salesforce/apex/WorkspaceController.getOpportunityContacts" {
  export default function getOpportunityContacts(param: {opportunityId: any}): Promise<any>;
}
declare module "@salesforce/apex/WorkspaceController.getAssignableRoles" {
  export default function getAssignableRoles(param: {workspaceId: any}): Promise<any>;
}
declare module "@salesforce/apex/WorkspaceController.getWorkspaceUsers" {
  export default function getWorkspaceUsers(param: {workspaceId: any}): Promise<any>;
}
declare module "@salesforce/apex/WorkspaceController.addWorkspaceUser" {
  export default function addWorkspaceUser(param: {workspaceId: any, email: any, roleId: any}): Promise<any>;
}
declare module "@salesforce/apex/WorkspaceController.createEnvelope" {
  export default function createEnvelope(param: {workspaceId: any, envelopeName: any, documentIds: any}): Promise<any>;
}
declare module "@salesforce/apex/WorkspaceController.getWorkspaceEnvelopes" {
  export default function getWorkspaceEnvelopes(param: {workspaceId: any}): Promise<any>;
}
declare module "@salesforce/apex/WorkspaceController.getWorkspaceUploadRequests" {
  export default function getWorkspaceUploadRequests(param: {workspaceId: any}): Promise<any>;
}
declare module "@salesforce/apex/WorkspaceController.createUploadRequest" {
  export default function createUploadRequest(param: {workspaceId: any, name: any, description: any, dueDate: any, assigneeFirstName: any, assigneeLastName: any, assigneeEmail: any}): Promise<any>;
}
