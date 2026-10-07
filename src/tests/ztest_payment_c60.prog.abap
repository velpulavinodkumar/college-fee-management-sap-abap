*&---------------------------------------------------------------------*
*& Report ZTEST_PAYMENT_C60
*&---------------------------------------------------------------------*
*& Tests ZCL_PAYMENT_C60 (validate / submit / verify / reject).
*&
*& It uses ONE student fee row (default Y26ECE025 / Tuition Fee).
*& All test payments carry the transaction ID  ZTEST-xxx.
*& With "Clean up" ticked, the report removes its own test payments and
*& receipts at the end and puts the fee row back to unpaid.
*& (Receipt numbers that were used stay used - that is how number
*&  ranges work, so there will be gaps. Audit log lines are kept.)
*&---------------------------------------------------------------------*
REPORT ztest_payment_c60.

TYPES: BEGIN OF ty_fee,
         total_fee   TYPE zfee_details_c60-total_fee,
         concession  TYPE zfee_details_c60-concession,
         late_fee    TYPE zfee_details_c60-late_fee,
         paid_amount TYPE zfee_details_c60-paid_amount,
         balance     TYPE zfee_details_c60-balance,
         currency    TYPE zfee_details_c60-currency,
       END OF ty_fee.

PARAMETERS: p_reg   TYPE zstudent_cs60-reg_no DEFAULT 'Y26ECE025',
            p_fee   TYPE zfee_details_c60-fee_type DEFAULT 'Tuition Fee' LOWER CASE,
            p_acad  TYPE zfee_details_c60-academic_year DEFAULT '1',
            p_clean AS CHECKBOX DEFAULT 'X'.

DATA: gv_pass TYPE i,
      gv_fail TYPE i,
      gv_no   TYPE i.

*----------------------------------------------------------------------*
CLASS lcl_t DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS check IMPORTING iv_name TYPE csequence
                                  iv_ok   TYPE abap_bool
                                  iv_info TYPE csequence.
ENDCLASS.

CLASS lcl_t IMPLEMENTATION.
  METHOD check.
    gv_no = gv_no + 1.
    IF iv_ok = abap_true.
      gv_pass = gv_pass + 1.
      FORMAT COLOR COL_POSITIVE.
      WRITE: / 'PASS', gv_no LEFT-JUSTIFIED, iv_name.
    ELSE.
      gv_fail = gv_fail + 1.
      FORMAT COLOR COL_NEGATIVE.
      WRITE: / 'FAIL', gv_no LEFT-JUSTIFIED, iv_name.
    ENDIF.
    FORMAT COLOR OFF.
    IF iv_info IS NOT INITIAL.
      WRITE: / '       ->', iv_info.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

FORM read_fee CHANGING cs_fee TYPE ty_fee.
  CLEAR cs_fee.
  SELECT SINGLE total_fee, concession, late_fee, paid_amount, balance, currency
    FROM zfee_details_c60
    WHERE reg_no        = @p_reg
      AND academic_year = @p_acad
      AND fee_type      = @p_fee
    INTO CORRESPONDING FIELDS OF @cs_fee.
ENDFORM.

FORM read_status USING iv_pay_id TYPE zpayment_c60-payment_id
                 CHANGING cv_status TYPE zpayment_c60-status.
  CLEAR cv_status.
  SELECT SINGLE status FROM zpayment_c60
    WHERE payment_id = @iv_pay_id
    INTO @cv_status.
ENDFORM.

* Removes every ZTEST-xxx payment (and its receipt) and resets the fee row
FORM cleanup.
  SELECT payment_id FROM zpayment_c60
    WHERE reg_no = @p_reg
      AND transaction_id LIKE 'ZTEST-%'
    INTO TABLE @DATA(lt_ids).
  LOOP AT lt_ids INTO DATA(ls_id).
    DELETE FROM zreceipt_c60 WHERE pay_id = @ls_id-payment_id.
    DELETE FROM zpayment_c60 WHERE payment_id = @ls_id-payment_id.
  ENDLOOP.

  DATA ls_fee TYPE ty_fee.
  PERFORM read_fee CHANGING ls_fee.
  DATA(lv_full) = ls_fee-total_fee - ls_fee-concession + ls_fee-late_fee.
  UPDATE zfee_details_c60
    SET paid_amount = 0,
        balance     = @lv_full
    WHERE reg_no        = @p_reg
      AND academic_year = @p_acad
      AND fee_type      = @p_fee.
  COMMIT WORK.
ENDFORM.

*----------------------------------------------------------------------*
START-OF-SELECTION.
*----------------------------------------------------------------------*
  DATA: gs_fee0  TYPE ty_fee,
        gs_fee   TYPE ty_fee,
        gs_r     TYPE zcl_payment_c60=>ty_result,
        gv_id1   TYPE zpayment_c60-payment_id,
        gv_id2   TYPE zpayment_c60-payment_id,
        gv_rc1   TYPE zpayment_c60-receipt_no,
        gv_status TYPE zpayment_c60-status,
        gv_amt   TYPE zpayment_c60-amount,
        gv_expect TYPE zfee_details_c60-balance,
        gv_acad  TYPE zpayment_c60-academic_year,
        gv_user  TYPE zpayment_c60-entered_by.

  gv_acad = p_acad.
  gv_user = p_reg.

  " Leftovers from an earlier run that stopped half way
  SELECT SINGLE payment_id FROM zpayment_c60
    WHERE reg_no = @p_reg AND transaction_id LIKE 'ZTEST-%'
    INTO @DATA(lv_left).
  IF sy-subrc = 0.
    PERFORM cleanup.
  ENDIF.

  " The fee row must exist and be completely unpaid before we start
  PERFORM read_fee CHANGING gs_fee0.
  IF gs_fee0-total_fee IS INITIAL.
    WRITE: / 'Fee row not found for', p_reg, p_fee.
    WRITE: / 'Run ZFEE_DEMAND_GEN_C60 first, or choose another student.'.
    RETURN.
  ENDIF.
  IF gs_fee0-paid_amount <> 0.
    WRITE: / 'This fee row already has real payments on it.'.
    WRITE: / 'Choose a student with no payments (for example Y26ECE025).'.
    RETURN.
  ENDIF.

  WRITE: / 'Testing on', p_reg, p_fee, 'Balance before:', gs_fee0-balance CURRENCY gs_fee0-currency.
  ULINE.

  "---- 1. Valid submission -------------------------------------------
  gs_r = zcl_payment_c60=>submit(
           iv_reg_no = p_reg iv_fee_type = p_fee iv_acad_year = gv_acad
           iv_amount = '10000.00' iv_txn_id = 'ZTEST-001'
           iv_mode = 'UPI' iv_bank = 'Test Bank' iv_entered = gv_user ).
  gv_id1 = gs_r-payment_id.
  PERFORM read_status USING gv_id1 CHANGING gv_status.
  PERFORM read_fee CHANGING gs_fee.
  lcl_t=>check( iv_name = 'Valid submission is accepted and saved as SUBMITTED'
                iv_ok   = xsdbool( gs_r-ok = abap_true AND gv_status = 'SUBMITTED' )
                iv_info = gs_r-message ).

  "---- 2. Balance must NOT change at submission ------------------------
  lcl_t=>check( iv_name = 'Balance is unchanged after submission'
                iv_ok   = xsdbool( gs_fee-balance = gs_fee0-balance AND gs_fee-paid_amount = 0 )
                iv_info = |Balance now { gs_fee-balance CURRENCY = gs_fee-currency }| ).

  "---- 3. Duplicate transaction ID -------------------------------------
  gs_r = zcl_payment_c60=>submit(
           iv_reg_no = p_reg iv_fee_type = p_fee iv_acad_year = gv_acad
           iv_amount = '1000.00' iv_txn_id = 'ZTEST-001'
           iv_mode = 'UPI' iv_bank = 'Test Bank' iv_entered = gv_user ).
  lcl_t=>check( iv_name = 'Duplicate transaction ID is blocked'
                iv_ok   = xsdbool( gs_r-ok = abap_false )
                iv_info = gs_r-message ).

  "---- 4. Amount above the balance --------------------------------------
  gv_amt = gs_fee0-balance + 1.
  gs_r = zcl_payment_c60=>validate(
           iv_reg_no = p_reg iv_fee_type = p_fee iv_acad_year = gv_acad
           iv_amount = gv_amt iv_txn_id = 'ZTEST-OVER' ).
  lcl_t=>check( iv_name = 'Amount above the balance is blocked'
                iv_ok   = xsdbool( gs_r-ok = abap_false )
                iv_info = gs_r-message ).

  "---- 5. Zero amount ---------------------------------------------------
  gs_r = zcl_payment_c60=>validate(
           iv_reg_no = p_reg iv_fee_type = p_fee iv_acad_year = gv_acad
           iv_amount = '0.00' iv_txn_id = 'ZTEST-ZERO' ).
  lcl_t=>check( iv_name = 'Zero amount is blocked'
                iv_ok   = xsdbool( gs_r-ok = abap_false )
                iv_info = gs_r-message ).

  "---- 6. Verify: receipt number and balance ----------------------------
  gs_r = zcl_payment_c60=>verify( iv_payment_id = gv_id1 iv_verifier = 'TESTACC' ).
  gv_rc1 = gs_r-receipt_no.
  PERFORM read_fee CHANGING gs_fee.
  gv_expect = gs_fee0-balance - '10000.00'.
  lcl_t=>check( iv_name = 'Verify creates a receipt number like FR/2026/000125'
                iv_ok   = xsdbool( gs_r-ok = abap_true AND gv_rc1(3) = 'FR/' AND strlen( condense( gv_rc1 ) ) = 14 )
                iv_info = |Receipt: { gv_rc1 }  { gs_r-message }| ).
  lcl_t=>check( iv_name = 'Verify reduces the balance by the amount paid'
                iv_ok   = xsdbool( gs_fee-balance = gv_expect AND gs_fee-paid_amount = '10000.00' )
                iv_info = |Paid { gs_fee-paid_amount CURRENCY = gs_fee-currency }, balance { gs_fee-balance CURRENCY = gs_fee-currency }| ).

  "---- 7. Receipt row exists and points to the payment ------------------
  SELECT SINGLE pay_id FROM zreceipt_c60
    WHERE receipt_no = @gv_rc1
    INTO @DATA(lv_pay_in_rcpt).
  lcl_t=>check( iv_name = 'Receipt row is saved in ZRECEIPT_C60 and linked to the payment'
                iv_ok   = xsdbool( sy-subrc = 0 AND lv_pay_in_rcpt = gv_id1 )
                iv_info = '' ).

  "---- 8. Verifying the same payment twice ------------------------------
  gs_r = zcl_payment_c60=>verify( iv_payment_id = gv_id1 iv_verifier = 'TESTACC' ).
  PERFORM read_fee CHANGING gs_fee.
  lcl_t=>check( iv_name = 'Verifying an already VERIFIED payment is blocked'
                iv_ok   = xsdbool( gs_r-ok = abap_false AND gs_fee-balance = gv_expect )
                iv_info = gs_r-message ).

  "---- 9. Reject needs a remark -----------------------------------------
  gs_r = zcl_payment_c60=>submit(
           iv_reg_no = p_reg iv_fee_type = p_fee iv_acad_year = gv_acad
           iv_amount = '6000.00' iv_txn_id = 'ZTEST-002'
           iv_mode = 'NEFT' iv_bank = 'Test Bank' iv_entered = gv_user ).
  gv_id2 = gs_r-payment_id.
  gs_r = zcl_payment_c60=>reject( iv_payment_id = gv_id2 iv_verifier = 'TESTACC' iv_remark = '' ).
  lcl_t=>check( iv_name = 'Reject without a remark is blocked'
                iv_ok   = xsdbool( gs_r-ok = abap_false )
                iv_info = gs_r-message ).

  "---- 10. Reject with a remark ----------------------------------------
  gs_r = zcl_payment_c60=>reject( iv_payment_id = gv_id2 iv_verifier = 'TESTACC'
                                  iv_remark = 'UTR not found in bank statement' ).
  PERFORM read_status USING gv_id2 CHANGING gv_status.
  PERFORM read_fee CHANGING gs_fee.
  lcl_t=>check( iv_name = 'Reject with a remark works and the balance stays the same'
                iv_ok   = xsdbool( gs_r-ok = abap_true AND gv_status = 'REJECTED' AND gs_fee-balance = gv_expect )
                iv_info = gs_r-message ).

  "---- 11. A rejected payment cannot be verified -----------------------
  gs_r = zcl_payment_c60=>verify( iv_payment_id = gv_id2 iv_verifier = 'TESTACC' ).
  lcl_t=>check( iv_name = 'A REJECTED payment cannot be verified'
                iv_ok   = xsdbool( gs_r-ok = abap_false )
                iv_info = gs_r-message ).

  "---- 12. Resubmit the same UTR after the rejection --------------------
  gs_r = zcl_payment_c60=>submit(
           iv_reg_no = p_reg iv_fee_type = p_fee iv_acad_year = gv_acad
           iv_amount = '6000.00' iv_txn_id = 'ZTEST-002'
           iv_mode = 'NEFT' iv_bank = 'Test Bank' iv_entered = gv_user ).
  lcl_t=>check( iv_name = 'A rejected payment can be resubmitted with the same reference'
                iv_ok   = xsdbool( gs_r-ok = abap_true )
                iv_info = gs_r-message ).
  gv_id2 = gs_r-payment_id.

  "---- 13. Second verification: new receipt number and partial balance --
  gs_r = zcl_payment_c60=>verify( iv_payment_id = gv_id2 iv_verifier = 'TESTACC' ).
  PERFORM read_fee CHANGING gs_fee.
  gv_expect = gs_fee0-balance - '16000.00'.
  lcl_t=>check( iv_name = 'Second receipt number is different (unique)'
                iv_ok   = xsdbool( gs_r-ok = abap_true AND gs_r-receipt_no <> gv_rc1 )
                iv_info = |Receipt: { gs_r-receipt_no }| ).
  lcl_t=>check( iv_name = 'Partial payments add up (10,000 + 6,000 paid, rest still due)'
                iv_ok   = xsdbool( gs_fee-balance = gv_expect AND gs_fee-paid_amount = '16000.00' )
                iv_info = |Paid { gs_fee-paid_amount CURRENCY = gs_fee-currency }, balance { gs_fee-balance CURRENCY = gs_fee-currency }| ).

  "---- 14. Audit log has the actions ------------------------------------
  SELECT COUNT(*) FROM zaudit_log_c60
    WHERE user_id = 'TESTACC'
    INTO @DATA(lv_logs).
  lcl_t=>check( iv_name = 'Audit log has VERIFY and REJECT entries'
                iv_ok   = xsdbool( lv_logs >= 3 )
                iv_info = |{ lv_logs } log lines for TESTACC| ).

  "---- Result -----------------------------------------------------------
  ULINE.
  WRITE: / 'Passed:', gv_pass, '  Failed:', gv_fail.

  IF p_clean = abap_true.
    PERFORM cleanup.
    WRITE: / 'Clean-up done: test payments and receipts removed, fee row reset to unpaid.'.
  ELSE.
    WRITE: / 'Clean-up skipped: test payments are still in the tables.'.
  ENDIF.
