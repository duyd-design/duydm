CLASS zcl_fi_map_bp DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ts_email,
        ordinal_number TYPE string,
        email_address  TYPE string,
      END OF ts_email,
      tt_email TYPE STANDARD TABLE OF ts_email WITH DEFAULT KEY,

      BEGIN OF ts_phone,
        ordinal_number TYPE string,
        phone_number   TYPE string,
      END OF ts_phone,
      tt_phone TYPE STANDARD TABLE OF ts_phone WITH DEFAULT KEY,

      BEGIN OF ts_address,
        country        TYPE string,
        region         TYPE string,
        city_name      TYPE string,
        street_name    TYPE string,
        postal_code    TYPE string,
        language       TYPE string,
        transport_zone TYPE string,
        link_email     TYPE tt_email,
        link_phone     TYPE tt_phone,
      END OF ts_address,
      tt_address TYPE STANDARD TABLE OF ts_address WITH DEFAULT KEY,

      BEGIN OF ts_role,
        business_partner_role TYPE string,
      END OF ts_role,
      tt_role TYPE STANDARD TABLE OF ts_role WITH DEFAULT KEY,

      BEGIN OF ts_tax_number,
        bp_tax_type   TYPE string,
        bp_tax_number TYPE string,
      END OF ts_tax_number,
      tt_tax_number TYPE STANDARD TABLE OF ts_tax_number WITH DEFAULT KEY,

      BEGIN OF ts_sales_area_tax,
        departure_country           TYPE string,
        customer_tax_category       TYPE string,
        customer_tax_classification TYPE string,
      END OF ts_sales_area_tax,
      tt_sales_area_tax TYPE STANDARD TABLE OF ts_sales_area_tax WITH DEFAULT KEY,

      BEGIN OF ts_sales_area,
        sales_organization            TYPE string,
        distribution_channel          TYPE string,
        division                      TYPE string,
        currency                      TYPE string,
        customer_payment_terms        TYPE string,
        customer_payment_method       TYPE string,
        incoterms_version             TYPE string,
        incoterms_classification      TYPE string,
        incoterms_location1           TYPE string,
        customer_group                TYPE string,
        sales_district                TYPE string,
        sales_office                  TYPE string,
        sales_group                   TYPE string,
        delivery_priority             TYPE string,
        order_combination_is_allowed  TYPE abap_bool,
        shipping_condition            TYPE string,
        supplying_plant               TYPE string,
        cust_account_assignment_group TYPE string,
        additional_customer_group1    TYPE string,
        additional_customer_group2    TYPE string,
        additional_customer_group3    TYPE string,
        additional_customer_group4    TYPE string,
        additional_customer_group5    TYPE string,
        link_sales_area_tax           TYPE tt_sales_area_tax,
      END OF ts_sales_area,
      tt_sales_area TYPE STANDARD TABLE OF ts_sales_area WITH DEFAULT KEY,

      BEGIN OF ts_company,
        company_code           TYPE string,
        reconciliation_account TYPE string,
        payment_terms          TYPE string,
      END OF ts_company,
      tt_company TYPE STANDARD TABLE OF ts_company WITH DEFAULT KEY,

      BEGIN OF ts_customer,
        link_sales_area TYPE tt_sales_area,
        link_company    TYPE tt_company,
      END OF ts_customer,

      BEGIN OF ts_business_partner,
        bp_id_by_ext_system       TYPE string,
        business_partner_category TYPE string,
        business_partner_grouping TYPE string,
        organization_bp_name1     TYPE string,
        search_term1              TYPE string,
        link_address              TYPE tt_address,
        link_role                 TYPE tt_role,
        link_tax_number           TYPE tt_tax_number,
        link_customer             TYPE ts_customer,
      END OF ts_business_partner.

    METHODS:
      " Parse JSON (đã ở định dạng SAP, map sẵn bên Shopify) -> struct ABAP.
      " KHÔNG áp default - mọi giá trị nghiệp vụ đều lấy nguyên từ payload.
      map_bp
        IMPORTING
          iv_json  TYPE string
        EXPORTING
          es_bp    TYPE ts_business_partner
          ev_error TYPE string.

  PRIVATE SECTION.

    METHODS:
      normalize_inbound
        IMPORTING iv_json        TYPE string
        RETURNING VALUE(rv_json) TYPE string,

      validate_bp
        IMPORTING is_bp           TYPE ts_business_partner
        RETURNING VALUE(rv_error) TYPE string.

ENDCLASS.



CLASS ZCL_FI_MAP_BP IMPLEMENTATION.


  METHOD map_bp.

    CLEAR: es_bp, ev_error.

    IF iv_json IS INITIAL.
      ev_error = 'Request body is empty'.
      RETURN.
    ENDIF.

    DATA(lv_json) = normalize_inbound( iv_json ).

    TRY.
        /ui2/cl_json=>deserialize(
          EXPORTING json        = lv_json
                    pretty_name = /ui2/cl_json=>pretty_mode-pascal_case
          CHANGING  data        = es_bp ).
      CATCH cx_root INTO DATA(lx_json).
        ev_error = |Invalid JSON: { lx_json->get_text( ) }|.
        RETURN.
    ENDTRY.

    ev_error = validate_bp( es_bp ).

  ENDMETHOD.


  METHOD normalize_inbound.

    rv_json = iv_json.

    " Nav property SAP dùng tiền tố "to_" -> đổi sang tên field ABAP tương ứng
    REPLACE ALL OCCURRENCES OF '"to_BusinessPartnerAddress"' IN rv_json WITH '"LinkAddress"'.
    REPLACE ALL OCCURRENCES OF '"to_BusinessPartnerRole"'    IN rv_json WITH '"LinkRole"'.
    REPLACE ALL OCCURRENCES OF '"to_BusinessPartnerTax"'     IN rv_json WITH '"LinkTaxNumber"'.
    REPLACE ALL OCCURRENCES OF '"to_Customer"'               IN rv_json WITH '"LinkCustomer"'.
    REPLACE ALL OCCURRENCES OF '"to_CustomerSalesArea"'      IN rv_json WITH '"LinkSalesArea"'.
    REPLACE ALL OCCURRENCES OF '"to_CustomerCompany"'        IN rv_json WITH '"LinkCompany"'.
    REPLACE ALL OCCURRENCES OF '"to_SalesAreaTax"'           IN rv_json WITH '"LinkSalesAreaTax"'.
    REPLACE ALL OCCURRENCES OF '"to_EmailAddress"'           IN rv_json WITH '"LinkEmail"'.
    REPLACE ALL OCCURRENCES OF '"to_PhoneNumber"'            IN rv_json WITH '"LinkPhone"'.

    " Field có chữ viết tắt liền nhau (ID, BP) mà pascal_case không tách đúng
    REPLACE ALL OCCURRENCES OF '"BusinessPartnerIDByExtSystem"' IN rv_json WITH '"BpIdByExtSystem"'.
    REPLACE ALL OCCURRENCES OF '"OrganizationBPName1"'          IN rv_json WITH '"OrganizationBpName1"'.
    REPLACE ALL OCCURRENCES OF '"BPTaxType"'                    IN rv_json WITH '"BpTaxType"'.
    REPLACE ALL OCCURRENCES OF '"BPTaxNumber"'                  IN rv_json WITH '"BpTaxNumber"'.
    REPLACE ALL OCCURRENCES OF '"CustomerAccountAssignmentGroup"'
                                                                IN rv_json WITH '"CustAccountAssignmentGroup"'.

  ENDMETHOD.


  METHOD validate_bp.

    IF is_bp-bp_id_by_ext_system IS INITIAL.
      rv_error = 'BusinessPartnerIDByExtSystem is missing'.
      RETURN.
    ENDIF.

    IF is_bp-organization_bp_name1 IS INITIAL.
      rv_error = 'OrganizationBPName1 is missing'.
      RETURN.
    ENDIF.

    IF is_bp-business_partner_category IS INITIAL.
      rv_error = 'BusinessPartnerCategory is missing'.
      RETURN.
    ENDIF.

    IF is_bp-business_partner_grouping IS INITIAL.
      rv_error = 'BusinessPartnerGrouping is missing'.
      RETURN.
    ENDIF.

    IF is_bp-link_role IS INITIAL.
      rv_error = 'to_BusinessPartnerRole is missing'.
      RETURN.
    ENDIF.

    IF is_bp-link_address IS INITIAL.
      rv_error = 'to_BusinessPartnerAddress is missing'.
      RETURN.
    ENDIF.

  ENDMETHOD.
ENDCLASS.
