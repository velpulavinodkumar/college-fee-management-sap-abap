*&---------------------------------------------------------------------*
*& Report ZACC_VERIFY_C60
*&---------------------------------------------------------------------*
*& Step 14 - Accountant verification screen
*&
*&  1. The accountant logs in (accountants only).
*&  2. The list shows every payment waiting for verification.
*&  3. DOUBLE-CLICK a row:
*&       Approve -> receipt number is created, the balance is updated,
*&                  the audit log is written (all in one unit).
*&       Reject  -> a reason is asked, the payment is marked REJECTED.
*&  4. The list refreshes by itself after every action.
*&---------------------------------------------------------------------*
REPORT zacc_verify_c60.

TYPES: BEGIN OF ty_pay,
         payment_id     TYPE zpayment_c60-payment_id,
         payment_date   TYPE zpayment_c60-payment_date,
         reg_no         TYPE zpayment_c60-reg_no,
         name           TYPE zstudent_cs60-name,
         fee_type       TYPE zpayment_c60-fee_type,
         amount         TYPE zpayment_c60-amount,
         currency       TYPE zpayment_c60-currency,
         payment_mode   TYPE zpayment_c60-payment_mode,
         transaction_id TYPE zpayment_c60-transaction_id,
         bank_name      TYPE zpayment_c60-bank_name,
         entered_by     TYPE zpayment_c60-entered_by,
         status         TYPE zpayment_c60-status,
         receipt_no     TYPE zpayment_c60-receipt_no,
         remark         TYPE zpayment_c60-remark,
       END OF ty_pay.

DATA: gt_pay TYPE STANDARD TABLE OF ty_pay,
      go_alv TYPE REF TO cl_salv_table,
      gv_by  TYPE zpayment_c60-verified_by.

*----------------------------------------------------------------------*
* Selection screen
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE t_b1.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(22) c_user FOR FIELD p_user.
    PARAMETERS p_user TYPE zusers_c60-user_id OBLIGATORY.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(22) c_pass FOR FIELD p_pass.
    PARAMETERS p_pass TYPE c LENGTH 30 LOWER CASE OBLIGATORY.
  SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE t_b2.
  SELECTION-SCREEN BEGIN OF LINE.
    PARAMETERS p_all AS CHECKBOX.
    SELECTION-SCREEN COMMENT 4(50) c_all FOR FIELD p_all.
  SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b2.

INITIALIZATION.
  t_b1   = 'Accountant log in'.
  t_b2   = 'Which payments?'.
  c_user = 'User ID (Employee ID)'.
  c_pass = 'Password'.
  c_all  = 'Also show VERIFIED and REJECTED payments'.

AT SELECTION-SCREEN OUTPUT.
  LOOP AT SCREEN.
    IF screen-name = 'P_PASS'.
      screen-invisible = 1.
      MODIFY SCREEN.
    ENDIF.
  ENDLOOP.

*----------------------------------------------------------------------*
* Reads the payments (called at the start and after every action)
*----------------------------------------------------------------------*
FORM load_data.
  DATA lr_status TYPE RANGE OF zpayment_c60-status.
  IF p_all IS INITIAL.
    lr_status = VALUE #( ( sign = 'I' option = 'EQ' low = 'SUBMITTED' ) ).
  ENDIF.

  CLEAR gt_pay.
  SELECT p~payment_id, p~payment_date, p~reg_no, s~name, p~fee_type, p~amount,
         p~currency, p~payment_mode, p~transaction_id, p~bank_name,
         p~entered_by, p~status, p~receipt_no, p~remark
    FROM zpayment_c60 AS p
    LEFT OUTER JOIN zstudent_cs60 AS s ON s~reg_no = p~reg_no
    WHERE p~status IN @lr_status
    ORDER BY p~payment_id
    INTO CORRESPONDING FIELDS OF TABLE @gt_pay.
ENDFORM.

*----------------------------------------------------------------------*
* Double-click on a row = Approve or Reject
*----------------------------------------------------------------------*
CLASS lcl_h DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS on_double_click
      FOR EVENT double_click OF cl_salv_events_table
      IMPORTING row column.
ENDCLASS.

CLASS lcl_h IMPLEMENTATION.
  METHOD on_double_click.
    DATA: lv_ans    TYPE c LENGTH 1,
          lv_rc     TYPE c LENGTH 1,
          lv_text   TYPE c LENGTH 200,
          lv_remark TYPE zpayment_c60-remark,
          lv_like   TYPE c LENGTH 1,
          lt_sval   TYPE STANDARD TABLE OF sval,
          ls_res    TYPE zcl_payment_c60=>ty_result.

    READ TABLE gt_pay INTO DATA(ls_pay) INDEX row.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    IF ls_pay-status <> 'SUBMITTED'.
      MESSAGE |Payment { ls_pay-payment_id } is { ls_pay-status }. Only SUBMITTED payments can be processed.|
              TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    lv_text = |{ ls_pay-reg_no } { ls_pay-name } - { ls_pay-fee_type } - | &&
              |{ ls_pay-amount CURRENCY = ls_pay-currency } { ls_pay-currency } by { ls_pay-payment_mode } | &&
              |Ref: { ls_pay-transaction_id } Bank: { ls_pay-bank_name }. | &&
              |Did you check this in the bank statement?|.

    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        titlebar              = 'Verify payment'
        text_question         = lv_text
        text_button_1         = 'Approve'
        text_button_2         = 'Reject'
        default_button        = '1'
        display_cancel_button = 'X'
      IMPORTING
        answer                = lv_ans
      EXCEPTIONS
        text_not_found        = 1
        OTHERS                = 2.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    CASE lv_ans.
      WHEN '1'.                                   " Approve
        ls_res = zcl_payment_c60=>verify( iv_payment_id = ls_pay-payment_id
                                          iv_verifier   = gv_by ).

      WHEN '2'.                                   " Reject - ask for the reason
        lt_sval = VALUE #( ( tabname   = 'ZPAYMENT_C60'
                             fieldname = 'REMARK'
                             fieldtext = 'Reason for rejection' ) ).
        CALL FUNCTION 'POPUP_GET_VALUES'
          EXPORTING
            popup_title     = 'Reject payment'
          IMPORTING
            returncode      = lv_rc
          TABLES
            fields          = lt_sval
          EXCEPTIONS
            error_in_fields = 1
            OTHERS          = 2.
        IF sy-subrc <> 0 OR lv_rc = 'A'.          " cancelled
          RETURN.
        ENDIF.
        READ TABLE lt_sval INDEX 1 INTO DATA(ls_sval).
        lv_remark = ls_sval-value.
        ls_res = zcl_payment_c60=>reject( iv_payment_id = ls_pay-payment_id
                                          iv_verifier   = gv_by
                                          iv_remark     = lv_remark ).

      WHEN OTHERS.                                " Cancel
        RETURN.
    ENDCASE.

    " Show the new situation and the result message
    PERFORM load_data.
    go_alv->refresh( ).

    IF ls_res-ok = abap_true.
      lv_like = 'S'.
    ELSE.
      lv_like = 'E'.
    ENDIF.
    MESSAGE ls_res-message TYPE 'S' DISPLAY LIKE lv_like.
  ENDMETHOD.
ENDCLASS.

*----------------------------------------------------------------------*
START-OF-SELECTION.
*----------------------------------------------------------------------*

  "1. Log in - accountants only
  DATA(ls_login) = zcl_auth_cs60=>login( iv_user_id  = p_user
                                         iv_password = CONV string( p_pass ) ).
  CLEAR p_pass.
  IF ls_login-ok = abap_false.
    MESSAGE ls_login-message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  IF ls_login-role <> 'A'.
    MESSAGE 'Only accountants can verify payments' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  gv_by = p_user.

  "2. Load and show the list
  PERFORM load_data.
  IF gt_pay IS INITIAL.
    MESSAGE 'No payments are waiting for verification' TYPE 'S'.
    RETURN.
  ENDIF.

  TRY.
      cl_salv_table=>factory( IMPORTING r_salv_table = go_alv
                              CHANGING  t_table      = gt_pay ).
    CATCH cx_salv_msg.
      MESSAGE 'Payment list could not be displayed' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
  ENDTRY.

  DATA(lo_cols) = go_alv->get_columns( ).
  lo_cols->set_optimize( abap_true ).
  go_alv->get_functions( )->set_all( abap_true ).
  go_alv->get_display_settings( )->set_striped_pattern( abap_true ).
  go_alv->get_display_settings( )->set_list_header(
    'Double-click a payment to Approve or Reject' ).
  go_alv->get_selections( )->set_selection_mode( if_salv_c_selection_mode=>single ).

  TRY.
      CAST cl_salv_column_table( lo_cols->get_column( 'AMOUNT' )
        )->set_currency_column( 'CURRENCY' ).
      lo_cols->get_column( 'CURRENCY' )->set_visible( abap_false ).
    CATCH cx_salv_not_found cx_salv_data_error.
      " Column names are fixed in TY_PAY, so this cannot normally happen
  ENDTRY.

  DATA(lo_events) = go_alv->get_event( ).
  SET HANDLER lcl_h=>on_double_click FOR lo_events.

  go_alv->display( ).
