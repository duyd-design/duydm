CLASS zcl_srvc_bp_integration DEFINITION
  PUBLIC
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_http_service_extension .

  PROTECTED SECTION.
  PRIVATE SECTION.

    METHODS:
      handle_post
        IMPORTING
          io_request  TYPE REF TO if_web_http_request
          io_response TYPE REF TO if_web_http_response,

      set_response
        IMPORTING
          io_response TYPE REF TO if_web_http_response
          iv_status   TYPE i
          iv_message  TYPE string
          iv_bp_id    TYPE string DEFAULT ''
          iv_shop_id  TYPE string DEFAULT ''.

ENDCLASS.



CLASS ZCL_SRVC_BP_INTEGRATION IMPLEMENTATION.


  METHOD if_http_service_extension~handle_request.

    CASE request->get_method( ).
      WHEN 'POST'.
        handle_post( io_request  = request
                     io_response = response ).
      WHEN OTHERS.
        set_response( io_response = response
                      iv_status   = 405
                      iv_message  = 'Method Not Allowed' ).
    ENDCASE.

  ENDMETHOD.


  METHOD handle_post.

    DATA(lv_body) = io_request->get_text( ).

    IF lv_body IS INITIAL.
      set_response( io_response = io_response
                    iv_status   = 400
                    iv_message  = 'Request body is empty' ).
      RETURN.
    ENDIF.

    DATA(lo_map)  = NEW zcl_fi_map_bp( ).
    DATA(lo_push) = NEW zcl_push_bp_data( ).

    lo_map->map_bp(
      EXPORTING iv_json  = lv_body
      IMPORTING es_bp    = DATA(ls_bp)
                ev_error = DATA(lv_map_err) ).

    IF lv_map_err IS NOT INITIAL.
      lo_push->write_log(
        iv_shopify_bp_id = ls_bp-bp_id_by_ext_system
        iv_sap_bp_id     = space
        iv_status        = 400
        iv_message       = lv_map_err ).

      set_response( io_response = io_response
                    iv_status   = 400
                    iv_message  = lv_map_err
                    iv_shop_id  = ls_bp-bp_id_by_ext_system ).
      RETURN.
    ENDIF.

    lo_push->push_bp(
      EXPORTING is_bp               = ls_bp
      IMPORTING ev_status           = DATA(lv_status)
                ev_message          = DATA(lv_message)
                ev_business_partner = DATA(lv_bp_number) ).

    set_response( io_response = io_response
                  iv_status   = lv_status
                  iv_message  = lv_message
                  iv_bp_id    = lv_bp_number
                  iv_shop_id  = ls_bp-bp_id_by_ext_system ).

  ENDMETHOD.


  METHOD set_response.

    TYPES: BEGIN OF ts_resp,
             status        TYPE i,
             message       TYPE string,
             sap_bp_id     TYPE string,
             shopify_bp_id TYPE string,
           END OF ts_resp.

    DATA(ls_resp) = VALUE ts_resp(
      status        = iv_status
      message       = iv_message
      sap_bp_id     = iv_bp_id
      shopify_bp_id = iv_shop_id ).

    DATA(lv_json) = /ui2/cl_json=>serialize(
                      data        = ls_resp
                      compress    = abap_false
                      pretty_name = /ui2/cl_json=>pretty_mode-low_case ).

    io_response->set_status( iv_status ).
    io_response->set_header_field( i_name  = 'Content-Type'
                                   i_value = 'application/json' ).
    io_response->set_text( lv_json ).

  ENDMETHOD.
ENDCLASS.
