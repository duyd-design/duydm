CLASS zcl_push_bp_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS:
      push_bp
        IMPORTING
          is_bp               TYPE zcl_fi_map_bp=>ts_business_partner
        EXPORTING
          ev_status           TYPE i
          ev_message          TYPE string
          ev_business_partner TYPE string,

      write_log
        IMPORTING
          iv_shopify_bp_id TYPE string
          iv_sap_bp_id     TYPE string OPTIONAL
          iv_status        TYPE i
          iv_message       TYPE string,

      extract_business_partner
        IMPORTING iv_json      TYPE string
        RETURNING VALUE(rv_bp) TYPE string,

      extract_error_message
        IMPORTING iv_json       TYPE string
        RETURNING VALUE(rv_msg) TYPE string.

  PRIVATE SECTION.

    CONSTANTS:
      gc_comm_scenario TYPE c LENGTH 30 VALUE 'YY1_SRVC_CS',
      gc_service_root  TYPE string
        VALUE '/sap/opu/odata/sap/API_BUSINESS_PARTNER',
      gc_entity_set    TYPE string VALUE 'A_BusinessPartner'.

    METHODS:
      get_csrf_token
        IMPORTING io_client       TYPE REF TO if_web_http_client
        EXPORTING ev_status       TYPE i
                  ev_message      TYPE string
                  ev_response     TYPE string
        RETURNING VALUE(rv_token) TYPE string,

      build_payload
        IMPORTING is_bp          TYPE zcl_fi_map_bp=>ts_business_partner
        RETURNING VALUE(rv_json) TYPE string.


ENDCLASS.



CLASS ZCL_PUSH_BP_DATA IMPLEMENTATION.


  METHOD push_bp.

    DATA lo_http_client TYPE REF TO if_web_http_client.
    DATA lv_csrf_status   TYPE i.
    DATA lv_csrf_msg      TYPE string.
    DATA lv_csrf_response TYPE string.

    TRY.
*        DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
*                                comm_scenario = gc_comm_scenario ).
*
*        lo_http_client = cl_web_http_client_manager=>create_by_http_destination( lo_destination ).


        DATA: lr_cscn TYPE if_com_scenario_factory=>ty_query-cscn_id_range.

        " find CA by scenario
        lr_cscn = VALUE #( ( sign = 'I' option = 'EQ' low = 'SAP_COM_0008' ) ).
        DATA(lo_factory) = cl_com_arrangement_factory=>create_instance( ).
        lo_factory->query_ca(
          EXPORTING
            is_query           = VALUE #( cscn_id_range = lr_cscn )
          IMPORTING
            et_com_arrangement = DATA(lt_ca) ).

        IF lt_ca IS INITIAL.
          EXIT.
        ENDIF.

        " take the first one
        DATA(lo_ca) = VALUE #( lt_ca[ 1 ] OPTIONAL ).

        DATA(lt_inb_service) = lo_ca->get_inbound_services( ).
        DATA(ls_inb_service) = VALUE #( lt_inb_service[ id = 'API_BUSINESS_PARTNER_0001_IWSG' ] OPTIONAL ).
        DATA(lv_url) = VALUE #( ls_inb_service-urls[ 1 ] OPTIONAL ).
        DATA(lo_http_destination) =
            cl_http_destination_provider=>create_by_url( lv_url ).

        lo_http_client = cl_web_http_client_manager=>create_by_http_destination( lo_http_destination ).



        DATA(lv_token) = get_csrf_token(
  EXPORTING io_client   = lo_http_client
  IMPORTING ev_status   = lv_csrf_status
            ev_message  = lv_csrf_msg
            ev_response = lv_csrf_response ).

        DATA(lv_json)  = build_payload( is_bp ).

        DATA(lo_req) = lo_http_client->get_http_request( ).
        lo_req->set_uri_path( |{ gc_service_root }/{ gc_entity_set }| ).
        lo_req->set_header_field( i_name = 'x-csrf-token' i_value = lv_token ).
        lo_req->set_header_field( i_name = 'content-type' i_value = 'application/json;charset=utf-8' ).
        lo_req->set_header_field( i_name = 'accept'       i_value = 'application/json' ).
        lo_req->set_text( lv_json ).

        DATA(lo_resp)     = lo_http_client->execute( if_web_http_client=>post ).
        DATA(lv_code)     = lo_resp->get_status( )-code.
        DATA(lv_response) = lo_resp->get_text( ).
        lo_http_client->close( ).

        ev_status = lv_code.

        IF lv_code >= 400.
          ev_message = extract_error_message( lv_response ).
        ELSE.
          ev_business_partner = extract_business_partner( lv_response ).

          IF ev_business_partner IS INITIAL.
            ev_status  = 500.
            ev_message = 'Created but cannot parse BusinessPartner from response'.
          ELSE.
            ev_message = |Business Partner { ev_business_partner } created successfully|.
          ENDIF.
        ENDIF.

      CATCH cx_web_http_client_error INTO DATA(lx_http).
        ev_status  = 503.
        ev_message = |HTTP error: { lx_http->get_text( ) }|.

      CATCH cx_root INTO DATA(lx_root).
        ev_status  = 500.
        ev_message = |Unexpected error: { lx_root->get_text( ) }|.
    ENDTRY.

    write_log(
      iv_shopify_bp_id = is_bp-bp_id_by_ext_system
      iv_sap_bp_id     = ev_business_partner
      iv_status        = ev_status
      iv_message       = ev_message ).

  ENDMETHOD.


  METHOD get_csrf_token.

    CLEAR rv_token.

    TRY.
        DATA(lo_req) = io_client->get_http_request( ).
*        lo_req->set_uri_path( |{ gc_service_root }/| ).
        lo_req->set_header_field( i_name  = 'x-csrf-token'
                                  i_value = 'Fetch' ).

        lo_req->set_authorization_basic(
     EXPORTING
       i_username = 'SHOPIFY_ACCOUNT'
       i_password = 'SPiVh8XXU]C4)JfnuRprHM(l%@K+P(i=bcM9)nu2'
*           RECEIVING
*             r_value    =
   ).


        DATA(lo_resp) = io_client->execute( if_web_http_client=>get ).

        ev_status   = lo_resp->get_status( )-code.
        ev_response = lo_resp->get_text( ).
        rv_token    = lo_resp->get_header_field( 'x-csrf-token' ).

        IF ev_status <> 200 OR rv_token IS INITIAL.
          CLEAR rv_token.
          ev_message = |CSRF fetch failed - HTTP { ev_status }: {
                          substring( val = ev_response
                            len = COND i( WHEN strlen( ev_response ) > 300
                                          THEN 300
                                          ELSE strlen( ev_response ) ) ) }|.
        ENDIF.

      CATCH cx_root INTO DATA(lx_root).
        CLEAR rv_token.
        ev_status  = 500.
        ev_message = |CSRF exception: { lx_root->get_text( ) }|.
    ENDTRY.

  ENDMETHOD.


  METHOD build_payload.

    /ui2/cl_json=>serialize(
      EXPORTING
        data           = is_bp
        pretty_name    = /ui2/cl_json=>pretty_mode-pascal_case
        compress       = 'X'
        numc_as_string = 'X'
      RECEIVING
        r_json         = rv_json ).

    REPLACE ALL OCCURRENCES OF 'LinkSalesAreaTax' IN rv_json WITH 'to_SalesAreaTax'.
    REPLACE ALL OCCURRENCES OF 'LinkSalesArea'    IN rv_json WITH 'to_CustomerSalesArea'.
    REPLACE ALL OCCURRENCES OF 'LinkCompany'      IN rv_json WITH 'to_CustomerCompany'.
    REPLACE ALL OCCURRENCES OF 'LinkCustomer'     IN rv_json WITH 'to_Customer'.
    REPLACE ALL OCCURRENCES OF 'LinkAddress'      IN rv_json WITH 'to_BusinessPartnerAddress'.
    REPLACE ALL OCCURRENCES OF 'LinkRole'         IN rv_json WITH 'to_BusinessPartnerRole'.
    REPLACE ALL OCCURRENCES OF 'LinkTaxNumber'    IN rv_json WITH 'to_BusinessPartnerTax'.
    REPLACE ALL OCCURRENCES OF 'LinkEmail'        IN rv_json WITH 'to_EmailAddress'.
    REPLACE ALL OCCURRENCES OF 'LinkPhone'        IN rv_json WITH 'to_PhoneNumber'.

    REPLACE ALL OCCURRENCES OF 'BpIdByExtSystem'            IN rv_json WITH 'BusinessPartnerIDByExtSystem'.
    REPLACE ALL OCCURRENCES OF 'OrganizationBpName1'        IN rv_json WITH 'OrganizationBPName1'.
    REPLACE ALL OCCURRENCES OF 'BpTaxType'                  IN rv_json WITH 'BPTaxType'.
    REPLACE ALL OCCURRENCES OF 'BpTaxNumber'                IN rv_json WITH 'BPTaxNumber'.
    REPLACE ALL OCCURRENCES OF 'CustAccountAssignmentGroup' IN rv_json WITH 'CustomerAccountAssignmentGroup'.

  ENDMETHOD.


  METHOD extract_business_partner.

    TYPES: BEGIN OF ty_d,
             business_partner TYPE string,
           END OF ty_d,
           BEGIN OF ty_root_v2,
             d TYPE ty_d,
           END OF ty_root_v2,
           BEGIN OF ty_root_v4,
             business_partner TYPE string,
           END OF ty_root_v4.

    DATA ls_v2 TYPE ty_root_v2.
    DATA ls_v4 TYPE ty_root_v4.

    TRY.
        /ui2/cl_json=>deserialize(
          EXPORTING json        = iv_json
                    pretty_name = /ui2/cl_json=>pretty_mode-pascal_case
          CHANGING  data        = ls_v2 ).
        rv_bp = ls_v2-d-business_partner.
      CATCH cx_root.
        CLEAR rv_bp.
    ENDTRY.

    IF rv_bp IS NOT INITIAL.
      RETURN.
    ENDIF.

    TRY.
        /ui2/cl_json=>deserialize(
          EXPORTING json        = iv_json
                    pretty_name = /ui2/cl_json=>pretty_mode-pascal_case
          CHANGING  data        = ls_v4 ).
        rv_bp = ls_v4-business_partner.
      CATCH cx_root.
        CLEAR rv_bp.
    ENDTRY.

  ENDMETHOD.


  METHOD extract_error_message.

    TYPES: BEGIN OF ty_msg,
             value TYPE string,
           END OF ty_msg,
           BEGIN OF ty_detail,
             message TYPE string,
           END OF ty_detail,
           tt_detail TYPE STANDARD TABLE OF ty_detail WITH DEFAULT KEY,
           BEGIN OF ty_innererror,
             errordetails TYPE tt_detail,
           END OF ty_innererror,
           BEGIN OF ty_error,
             code       TYPE string,
             message    TYPE ty_msg,
             innererror TYPE ty_innererror,
           END OF ty_error,
           BEGIN OF ty_root,
             error TYPE ty_error,
           END OF ty_root.

    DATA ls_root TYPE ty_root.

    TRY.
        /ui2/cl_json=>deserialize(
          EXPORTING json        = iv_json
                    pretty_name = /ui2/cl_json=>pretty_mode-camel_case
          CHANGING  data        = ls_root ).
      CATCH cx_root.
        rv_msg = COND #( WHEN strlen( iv_json ) > 200
                         THEN |{ iv_json(200) }...|
                         ELSE iv_json ).
        RETURN.
    ENDTRY.

    rv_msg = ls_root-error-message-value.

    LOOP AT ls_root-error-innererror-errordetails INTO DATA(ls_detail).
      IF ls_detail-message IS INITIAL OR ls_detail-message = rv_msg.
        CONTINUE.
      ENDIF.
      rv_msg = |{ rv_msg }; { ls_detail-message }|.
    ENDLOOP.

    IF rv_msg IS INITIAL.
      rv_msg = 'Unknown error from SAP API'.
    ENDIF.

  ENDMETHOD.


  METHOD write_log.

    DATA ls_log TYPE ztb_bp_log.

    TRY.
        ls_log-log_uuid = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
        RETURN.
    ENDTRY.

    ls_log-shopify_bp_id = iv_shopify_bp_id.
    ls_log-sap_bp_id     = iv_sap_bp_id.
    ls_log-status        = iv_status.
    ls_log-message       = iv_message.

    GET TIME STAMP FIELD DATA(lv_tsl).
    ls_log-created_at      = lv_tsl.
    ls_log-created_by      = sy-uname.
    ls_log-created_on      = cl_abap_context_info=>get_system_date( ).
    ls_log-last_changed_at = lv_tsl.
    ls_log-last_changed_by = sy-uname.
    ls_log-last_changed_on = ls_log-created_on.

    TRY.
        ls_log-created_by_desc = cl_abap_context_info=>get_user_formatted_name( ).
      CATCH cx_abap_context_info_error.
        ls_log-created_by_desc = sy-uname.
    ENDTRY.

    INSERT ztb_bp_log FROM @ls_log.

    IF sy-subrc = 0.
      COMMIT WORK.
    ELSE.
      ROLLBACK WORK.
    ENDIF.

  ENDMETHOD.
ENDCLASS.
