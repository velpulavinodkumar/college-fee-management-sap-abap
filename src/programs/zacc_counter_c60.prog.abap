*&---------------------------------------------------------------------*
*& Report ZACC_COUNTER_C60
*&---------------------------------------------------------------------*
*& Step 13 - Accountant counter entry (cash, DD, cheque)
*&
*&  A student pays at the college counter. The accountant:
*&    1. logs in,
*&    2. types the register number and the payment details,
*&    3. presses Execute (F8).
*&  The payment is saved. With "Verify now" ticked (default) the
*&  accountant has the money in hand, so it is approved at once and a
*&  receipt number is issued. Un-tick it to send the payment to the
*&  verification list (ZACC_VERIFY_C60) instead.
*&---------------------------------------------------------------------*
REPORT zacc_counter_c60.

DATA: gv_reg  TYPE zpayment_c60-reg_no,
      gv_by   TYPE zpayment_c60-entered_by,
      gv_ver  TYPE zpayment_c60-verified_by,
      gv_mode TYPE zpayment_c60-payment_mode,
      gv_txn  TYPE zpayment_c60-transaction_id,
      gv_like TYPE c LENGTH 1,
      gv_msg  TYPE string.

*----------------------------------------------------------------------*
* Selection screen
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE t_b1.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(24) c_user FOR FIELD p_user.
    PARAMETERS p_user TYPE zusers_c60-user_id OBLIGATORY.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(24) c_pass FOR FIELD p_pass.
    PARAMETERS p_pass TYPE c LENGTH 30 LOWER CASE OBLIGATORY.
  SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE t_b2.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(24) c_reg FOR FIELD p_reg.
    PARAMETERS p_reg TYPE zpayment_c60-reg_no OBLIGATORY.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(24) c_fee FOR FIELD p_fee.
    PARAMETERS p_fee TYPE zpayment_c60-fee_type LOWER CASE DEFAULT 'Tuition Fee'.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(24) c_acad FOR FIELD p_acad.
    PARAMETERS p_acad TYPE zpayment_c60-academic_year DEFAULT '1'.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(24) c_amt FOR FIELD p_amt.
    PARAMETERS p_amt TYPE zpayment_c60-amount OBLIGATORY.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(24) c_ref FOR FIELD p_ref.
    PARAMETERS p_ref TYPE zpayment_c60-transaction_id.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(24) c_bank FOR FIELD p_bank.
    PARAMETERS p_bank TYPE zpayment_c60-bank_name LOWER CASE.
  SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE t_b3.
  SELECTION-SCREEN BEGIN OF LINE.
    PARAMETERS p_cash RADIOBUTTON GROUP m DEFAULT 'X'.
    SELECTION-SCREEN COMMENT 4(30) c_cash FOR FIELD p_cash.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    PARAMETERS p_dd RADIOBUTTON GROUP m.
    SELECTION-SCREEN COMMENT 4(30) c_dd FOR FIELD p_dd.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    PARAMETERS p_chq RADIOBUTTON GROUP m.
    SELECTION-SCREEN COMMENT 4(30) c_chq FOR FIELD p_chq.
  SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b3.

SELECTION-SCREEN BEGIN OF BLOCK b4 WITH FRAME TITLE t_b4.
  SELECTION-SCREEN BEGIN OF LINE.
    PARAMETERS p_ver AS CHECKBOX DEFAULT 'X'.
    SELECTION-SCREEN COMMENT 4(60) c_ver FOR FIELD p_ver.
  SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b4.

INITIALIZATION.
  t_b1   = 'Accountant log in'.
  t_b2   = 'Payment received at the counter'.
  t_b3   = 'Payment mode'.
  t_b4   = 'After saving'.
  c_user = 'User ID (Employee ID)'.
  c_pass = 'Password'.
  c_reg  = 'Student register no.'.
  c_fee  = 'Fee type'.
  c_acad = 'Year of study'.
  c_amt  = 'Amount received'.
  c_ref  = 'Cheque / DD no. (optional for cash)'.
  c_bank = 'Bank name (DD / cheque)'.
  c_cash = 'Cash'.
  c_dd   = 'Demand Draft (DD)'.
  c_chq  = 'Cheque'.
  c_ver  = 'Verify now and issue the receipt'.

AT SELECTION-SCREEN OUTPUT.
  LOOP AT SCREEN.
    IF screen-name = 'P_PASS'.
      screen-invisible = 1.
      MODIFY SCREEN.
    ENDIF.
  ENDLOOP.

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
    MESSAGE 'Only accountants can record counter payments' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  gv_by  = p_user.
  gv_ver = p_user.
  gv_reg = p_reg.

  "2. The student must exist
  SELECT SINGLE name FROM zstudent_cs60
    WHERE reg_no = @gv_reg
    INTO @DATA(lv_name).
  IF sy-subrc <> 0.
    MESSAGE 'Register number not found in student records' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  "3. Mode and reference rules
  IF p_cash = abap_true.
    gv_mode = 'CASH'.
  ELSEIF p_dd = abap_true.
    gv_mode = 'DD'.
  ELSE.
    gv_mode = 'CHEQUE'.
  ENDIF.

  IF gv_mode <> 'CASH'.
    IF p_ref IS INITIAL.
      MESSAGE 'Enter the DD / cheque number' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    IF p_bank IS INITIAL.
      MESSAGE 'Enter the bank name' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
  ENDIF.
  gv_txn = to_upper( p_ref ).

  "4. Save the payment
  DATA(ls_sub) = zcl_payment_c60=>submit(
                   iv_reg_no    = gv_reg
                   iv_fee_type  = p_fee
                   iv_acad_year = p_acad
                   iv_amount    = p_amt
                   iv_txn_id    = gv_txn
                   iv_mode      = gv_mode
                   iv_bank      = p_bank
                   iv_entered   = gv_by ).
  IF ls_sub-ok = abap_false.
    MESSAGE ls_sub-message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  "5. Verify at once (the money is in the accountant's hand)
  DATA ls_ver TYPE zcl_payment_c60=>ty_result.
  IF p_ver = abap_true.
    ls_ver = zcl_payment_c60=>verify( iv_payment_id = ls_sub-payment_id
                                      iv_verifier   = gv_ver ).
  ENDIF.

  "6. Result
  WRITE: / 'COUNTER PAYMENT RECORDED'.
  ULINE.
  WRITE: / 'Student       :', gv_reg, lv_name,
         / 'Fee type      :', p_fee,
         / 'Amount        :', p_amt,
         / 'Mode          :', gv_mode,
         / 'Reference     :', gv_txn,
         / 'Payment ID    :', ls_sub-payment_id.
  ULINE.
  IF p_ver = abap_false.
    WRITE: / 'Status        : SUBMITTED - approve it in the verification screen'.
  ELSEIF ls_ver-ok = abap_true.
    WRITE: / 'Status        : VERIFIED',
           / 'Receipt no.   :', ls_ver-receipt_no.
  ELSE.
    WRITE: / 'Status        : SUBMITTED - could not verify now:', ls_ver-message.
    WRITE: / 'Approve it in the verification screen (ZACC_VERIFY_C60).'.
  ENDIF.

  IF p_ver = abap_true AND ls_ver-ok = abap_true.
    gv_msg = |Counter payment verified. Receipt { ls_ver-receipt_no }|.
    gv_like = 'S'.
  ELSEIF p_ver = abap_false.
    gv_msg = |Counter payment saved. ID { ls_sub-payment_id }|.
    gv_like = 'S'.
  ELSE.
    gv_msg = |Saved but not verified: { ls_ver-message }|.
    gv_like = 'E'.
  ENDIF.
  MESSAGE gv_msg TYPE 'S' DISPLAY LIKE gv_like.
