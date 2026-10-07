*&---------------------------------------------------------------------*
*& Report ZSTU_PAYMENT_C60
*&---------------------------------------------------------------------*
*& Step 12 - Student payment submission
*&
*&  1. The student logs in (User ID = register number).
*&  2. To pay: fill the payment block and press Execute (F8).
*&     The payment is saved as SUBMITTED. Nothing is paid yet - the
*&     accountant must verify it first (Step 14).
*&  3. To only look at your payments: leave the Amount empty.
*&  4. The list at the end shows all of the student's payments with
*&     their status (SUBMITTED / VERIFIED / REJECTED) and receipt number.
*&
*&  The student can only ever use his or her OWN register number: it is
*&  taken from the login, never typed on the screen.
*&---------------------------------------------------------------------*
REPORT zstu_payment_c60.

TYPES: BEGIN OF ty_hist,
         light       TYPE c LENGTH 1,
         payment_id  TYPE zpayment_c60-payment_id,
         payment_date TYPE zpayment_c60-payment_date,
         fee_type    TYPE zpayment_c60-fee_type,
         amount      TYPE zpayment_c60-amount,
         currency    TYPE zpayment_c60-currency,
         payment_mode TYPE zpayment_c60-payment_mode,
         transaction_id TYPE zpayment_c60-transaction_id,
         status      TYPE zpayment_c60-status,
         receipt_no  TYPE zpayment_c60-receipt_no,
         remark      TYPE zpayment_c60-remark,
       END OF ty_hist.

DATA: gt_hist TYPE STANDARD TABLE OF ty_hist,
      gv_msg  TYPE string.

*----------------------------------------------------------------------*
* Selection screen (all labels are set in INITIALIZATION, so you do not
* need to maintain any text elements)
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
    SELECTION-SCREEN COMMENT 1(22) c_fee FOR FIELD p_fee.
    PARAMETERS p_fee TYPE zpayment_c60-fee_type LOWER CASE DEFAULT 'Tuition Fee'.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(22) c_acad FOR FIELD p_acad.
    PARAMETERS p_acad TYPE zpayment_c60-academic_year DEFAULT '1'.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(22) c_amt FOR FIELD p_amt.
    PARAMETERS p_amt TYPE zpayment_c60-amount.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(22) c_txn FOR FIELD p_txn.
    PARAMETERS p_txn TYPE zpayment_c60-transaction_id.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(22) c_bank FOR FIELD p_bank.
    PARAMETERS p_bank TYPE zpayment_c60-bank_name LOWER CASE.
  SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE t_b3.
  SELECTION-SCREEN BEGIN OF LINE.
    PARAMETERS p_upi RADIOBUTTON GROUP m DEFAULT 'X'.
    SELECTION-SCREEN COMMENT 4(20) c_upi FOR FIELD p_upi.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    PARAMETERS p_neft RADIOBUTTON GROUP m.
    SELECTION-SCREEN COMMENT 4(20) c_neft FOR FIELD p_neft.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    PARAMETERS p_dd RADIOBUTTON GROUP m.
    SELECTION-SCREEN COMMENT 4(20) c_dd FOR FIELD p_dd.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    PARAMETERS p_chq RADIOBUTTON GROUP m.
    SELECTION-SCREEN COMMENT 4(20) c_chq FOR FIELD p_chq.
  SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b3.

INITIALIZATION.
  t_b1   = 'Step 1 - Log in'.
  t_b2   = 'Step 2 - Payment details (leave Amount empty to only view your payments)'.
  t_b3   = 'Payment mode'.
  c_user = 'User ID (Reg. No.)'.
  c_pass = 'Password'.
  c_fee  = 'Fee type'.
  c_acad = 'Year of study'.
  c_amt  = 'Amount paid'.
  c_txn  = 'UTR / Reference no.'.
  c_bank = 'Bank name'.
  c_upi  = 'UPI'.
  c_neft = 'NEFT / bank transfer'.
  c_dd   = 'Demand Draft (DD)'.
  c_chq  = 'Cheque'.

AT SELECTION-SCREEN OUTPUT.
  LOOP AT SCREEN.
    IF screen-name = 'P_PASS'.
      screen-invisible = 1.                  " hide the password
      MODIFY SCREEN.
    ENDIF.
  ENDLOOP.

*----------------------------------------------------------------------*
START-OF-SELECTION.
*----------------------------------------------------------------------*

  "1. Log in - students only
  DATA(ls_login) = zcl_auth_cs60=>login( iv_user_id  = p_user
                                         iv_password = CONV string( p_pass ) ).
  CLEAR p_pass.
  IF ls_login-ok = abap_false.
    MESSAGE ls_login-message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  IF ls_login-role <> 'S'.
    MESSAGE 'This screen is for students. Accountants use the counter entry screen.'
            TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " The student's register number is the login ID - never typed on screen.
  " (Variables are typed exactly like the class parameters.)
  DATA: gv_reg  TYPE zpayment_c60-reg_no,
        gv_by   TYPE zpayment_c60-entered_by,
        gv_like TYPE c LENGTH 1.
  gv_reg = p_user.
  gv_by  = p_user.

  "2. Submit a payment (only when an amount was typed)
  IF p_amt <> 0.

    DATA(gv_mode) = CONV zpayment_c60-payment_mode(
                      COND string( WHEN p_upi  = abap_true THEN 'UPI'
                                   WHEN p_neft = abap_true THEN 'NEFT'
                                   WHEN p_dd   = abap_true THEN 'DD'
                                   ELSE                         'CHEQUE' ) ).

    IF p_txn IS INITIAL.
      gv_msg = 'Enter the UTR / reference number of your payment'.
    ELSEIF p_bank IS INITIAL.
      gv_msg = 'Enter the bank name'.
    ELSE.
      DATA(ls_res) = zcl_payment_c60=>submit(
                       iv_reg_no    = gv_reg
                       iv_fee_type  = p_fee
                       iv_acad_year = p_acad
                       iv_amount    = p_amt
                       iv_txn_id    = CONV zpayment_c60-transaction_id( to_upper( p_txn ) )
                       iv_mode      = gv_mode
                       iv_bank      = p_bank
                       iv_entered   = gv_by ).
      gv_msg = ls_res-message.
    ENDIF.

    gv_like = COND #( WHEN ls_res-ok = abap_true THEN 'S' ELSE 'E' ).
    MESSAGE gv_msg TYPE 'S' DISPLAY LIKE gv_like.
  ENDIF.

  "3. This student's payments, newest first
  SELECT payment_id, payment_date, fee_type, amount, currency, payment_mode,
         transaction_id, status, receipt_no, remark
    FROM zpayment_c60
    WHERE reg_no = @gv_reg
    ORDER BY payment_id DESCENDING
    INTO CORRESPONDING FIELDS OF TABLE @gt_hist.

  IF gt_hist IS INITIAL.
    IF gv_msg IS INITIAL.
      MESSAGE 'You have not submitted any payment yet' TYPE 'S'.
    ENDIF.
    RETURN.
  ENDIF.

  LOOP AT gt_hist ASSIGNING FIELD-SYMBOL(<ls_h>).
    <ls_h>-light = SWITCH #( <ls_h>-status WHEN 'VERIFIED' THEN '3'
                                          WHEN 'SUBMITTED' THEN '2'
                                          ELSE '1' ).
  ENDLOOP.

  TRY.
      cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_alv)
                              CHANGING  t_table      = gt_hist ).
    CATCH cx_salv_msg.
      MESSAGE 'Payment list could not be displayed' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
  ENDTRY.

  DATA(lo_cols) = lo_alv->get_columns( ).
  lo_cols->set_optimize( abap_true ).
  lo_cols->set_exception_column( 'LIGHT' ).
  lo_alv->get_functions( )->set_all( abap_true ).
  lo_alv->get_display_settings( )->set_striped_pattern( abap_true ).
  lo_alv->get_display_settings( )->set_list_header(
    CONV #( COND string( WHEN gv_msg IS NOT INITIAL THEN gv_msg
                         ELSE |My payments - { gv_reg }| ) ) ).

  TRY.
      CAST cl_salv_column_table( lo_cols->get_column( 'AMOUNT' )
        )->set_currency_column( 'CURRENCY' ).
      lo_cols->get_column( 'CURRENCY' )->set_visible( abap_false ).
    CATCH cx_salv_not_found cx_salv_data_error.
      " Column names are fixed in TY_HIST, so this cannot normally happen
  ENDTRY.

  lo_alv->display( ).
