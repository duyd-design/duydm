@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BP Log'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_FI_BP_LOG as select from ztb_bp_log
{
    key log_uuid as LogUuid,
    key sap_bp_id as SapBpId,
    key shopify_bp_id as ShopifyBpId,
    status as Status,
    message as Message,
    created_at as CreatedAt,
    created_by as CreatedBy,
    created_on as CreatedOn,
    created_by_desc as CreatedByDesc,
    last_changed_at as LastChangedAt,
    last_changed_by as LastChangedBy,
    last_changed_on as LastChangedOn
}
