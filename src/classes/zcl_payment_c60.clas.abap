CLASS zcl_payment_c60 DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_result,
             ok         TYPE abap_bool,
             message    TYPE string,
             payment_id TYPE n LENGTH 10,
             receipt_no TYPE c LENGTH 16,
           END OF ty_result.

    CLASS-METHODS:
      validate  IMPORTING iv_reg_no    TYPE zpayment_c60-reg_no
                          iv_fee_type  TYPE zpayment_c60-fee_type
                          iv_acad_year TYPE zpayment_c60-academic_year
                          iv_amount    TYPE zpayment_c60-amount
                          iv_txn_id    TYPE zpayment_c60-transaction_id
                RETURNING VALUE(rs_result) TYPE ty_result,

      submit    IMPORTING iv_reg_no    TYPE zpayment_c60-reg_no
                          iv_fee_type  TYPE zpayment_c60-fee_type
                          iv_acad_year TYPE zpayment_c60-academic_year
                          iv_amount    TYPE zpayment_c60-amount
                          iv_txn_id    TYPE zpayment_c60-transaction_id
                          iv_mode      TYPE zpayment_c60-payment_mode
                          iv_bank      TYPE zpayment_c60-bank_name
                          iv_entered   TYPE zpayment_c60-entered_by
                RETURNING VALUE(rs_result) TYPE ty_result,

      verify    IMPORTING iv_payment_id TYPE zpayment_c60-payment_id
                          iv_verifier   TYPE zpayment_c60-verified_by
                RETURNING VALUE(rs_result) TYPE ty_result,

      reject    IMPORTING iv_payment_id TYPE zpayment_c60-payment_id
                          iv_verifier   TYPE zpayment_c60-verified_by
                          iv_remark     TYPE zpayment_c60-remark
                RETURNING VALUE(rs_result) TYPE ty_result.
ENDCLASS.



CLASS zcl_payment_c60 IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_PAYMENT_C60=>REJECT
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_PAYMENT_ID                  TYPE        ZPAYMENT_C60-PAYMENT_ID
* | [--->] IV_VERIFIER                    TYPE        ZPAYMENT_C60-VERIFIED_BY
* | [--->] IV_REMARK                      TYPE        ZPAYMENT_C60-REMARK
* | [<-()] RS_RESULT                      TYPE        TY_RESULT
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD reject.
    " A rejection must always say why
    IF iv_remark IS INITIAL.
      rs_result-message = 'A remark is required to reject a payment'.
      RETURN.
    ENDIF.

    SELECT SINGLE status FROM zpayment_c60
      WHERE payment_id = @iv_payment_id
      INTO @DATA(lv_status).
    IF sy-subrc <> 0.
      rs_result-message = 'Payment not found'.
      RETURN.
    ENDIF.
    IF lv_status <> 'SUBMITTED'.
      rs_result-message =
        |Payment is { lv_status }. Only SUBMITTED payments can be rejected.|.
      RETURN.
    ENDIF.

    UPDATE zpayment_c60
      SET status      = 'REJECTED',
          verified_by = @iv_verifier,
          verified_on = @sy-datum,
          remark      = @iv_remark
      WHERE payment_id = @iv_payment_id.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      rs_result-message = 'Rejection failed'.
      RETURN.
    ENDIF.

    DATA ls_log TYPE zaudit_log_c60.
    SELECT MAX( log_id ) FROM zaudit_log_c60 INTO @DATA(lv_max).
    ls_log-log_id     = lv_max + 1.
    ls_log-user_id    = iv_verifier.
    ls_log-action     = 'REJECT'.
    ls_log-object_key = |{ iv_payment_id }|.
    GET TIME STAMP FIELD ls_log-logged_at.
    ls_log-remark     = iv_remark.
    INSERT zaudit_log_c60 FROM @ls_log.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      rs_result-message = 'Rejection failed (audit log could not be written)'.
      RETURN.
    ENDIF.
    COMMIT WORK.

    rs_result-ok      = abap_true.
    rs_result-message =
      |Payment { iv_payment_id } rejected. Remark: { iv_remark }|.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_PAYMENT_C60=>SUBMIT
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_REG_NO                      TYPE        ZPAYMENT_C60-REG_NO
* | [--->] IV_FEE_TYPE                    TYPE        ZPAYMENT_C60-FEE_TYPE
* | [--->] IV_ACAD_YEAR                   TYPE        ZPAYMENT_C60-ACADEMIC_YEAR
* | [--->] IV_AMOUNT                      TYPE        ZPAYMENT_C60-AMOUNT
* | [--->] IV_TXN_ID                      TYPE        ZPAYMENT_C60-TRANSACTION_ID
* | [--->] IV_MODE                        TYPE        ZPAYMENT_C60-PAYMENT_MODE
* | [--->] IV_BANK                        TYPE        ZPAYMENT_C60-BANK_NAME
* | [--->] IV_ENTERED                     TYPE        ZPAYMENT_C60-ENTERED_BY
* | [<-()] RS_RESULT                      TYPE        TY_RESULT
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD submit.
    DATA ls_pay    TYPE zpayment_c60.
    DATA lv_pay_id TYPE n LENGTH 10.

    DATA(ls_val) = validate( iv_reg_no    = iv_reg_no
                             iv_fee_type  = iv_fee_type
                             iv_acad_year = iv_acad_year
                             iv_amount    = iv_amount
                             iv_txn_id    = iv_txn_id ).
    IF ls_val-ok = abap_false.
      rs_result-message = ls_val-message.
      RETURN.
    ENDIF.

    " Currency comes from the fee row, so reports show amounts correctly
    SELECT SINGLE currency FROM zfee_details_c60
      WHERE reg_no        = @iv_reg_no
        AND academic_year = @iv_acad_year
        AND fee_type      = @iv_fee_type
      INTO @DATA(lv_currency).

    CALL FUNCTION 'NUMBER_GET_NEXT'
      EXPORTING nr_range_nr = '01'
                object      = 'ZNR_PAYIDC'
      IMPORTING number      = lv_pay_id
      EXCEPTIONS OTHERS     = 1.
    IF sy-subrc <> 0.
      rs_result-message = 'Could not generate payment ID'.
      RETURN.
    ENDIF.

    ls_pay-payment_id     = lv_pay_id.
    ls_pay-reg_no         = iv_reg_no.
    ls_pay-fee_type       = iv_fee_type.
    ls_pay-academic_year  = iv_acad_year.
    ls_pay-transaction_id = iv_txn_id.
    ls_pay-currency       = lv_currency.
    ls_pay-amount         = iv_amount.
    ls_pay-payment_mode   = iv_mode.
    ls_pay-bank_name      = iv_bank.
    ls_pay-payment_date   = sy-datum.
    ls_pay-status         = 'SUBMITTED'.
    ls_pay-entered_by     = iv_entered.

    INSERT zpayment_c60 FROM @ls_pay.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      rs_result-message = 'Payment submission failed'.
      RETURN.
    ENDIF.
    COMMIT WORK.

    rs_result-ok         = abap_true.
    rs_result-payment_id = lv_pay_id.
    rs_result-message    =
      |Payment submitted. ID: { lv_pay_id }. Awaiting verification.|.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_PAYMENT_C60=>VALIDATE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_REG_NO                      TYPE        ZPAYMENT_C60-REG_NO
* | [--->] IV_FEE_TYPE                    TYPE        ZPAYMENT_C60-FEE_TYPE
* | [--->] IV_ACAD_YEAR                   TYPE        ZPAYMENT_C60-ACADEMIC_YEAR
* | [--->] IV_AMOUNT                      TYPE        ZPAYMENT_C60-AMOUNT
* | [--->] IV_TXN_ID                      TYPE        ZPAYMENT_C60-TRANSACTION_ID
* | [<-()] RS_RESULT                      TYPE        TY_RESULT
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD validate.
    IF iv_amount <= 0.
      rs_result-message = 'Amount must be greater than zero'.
      RETURN.
    ENDIF.

    SELECT SINGLE balance, currency
      FROM zfee_details_c60
      WHERE reg_no        = @iv_reg_no
        AND academic_year = @iv_acad_year
        AND fee_type      = @iv_fee_type
      INTO @DATA(ls_fee).
    IF sy-subrc <> 0.
      rs_result-message = 'Fee record not found for this student and fee type'.
      RETURN.
    ENDIF.

    IF iv_amount > ls_fee-balance.
      rs_result-message =
        |Amount { iv_amount } exceeds balance { ls_fee-balance }|.
      RETURN.
    ENDIF.

    " Duplicate UTR check. A REJECTED payment does not count, so the
    " student can resubmit the same reference after a rejection.
    IF iv_txn_id IS NOT INITIAL.
      SELECT SINGLE payment_id FROM zpayment_c60
        WHERE transaction_id = @iv_txn_id
          AND status        <> 'REJECTED'
        INTO @DATA(lv_dup).
      IF sy-subrc = 0.
        rs_result-message =
          |Transaction ID { iv_txn_id } already exists|.
        RETURN.
      ENDIF.
    ENDIF.

    rs_result-ok = abap_true.
    rs_result-message = 'Validation passed'.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_PAYMENT_C60=>VERIFY
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_PAYMENT_ID                  TYPE        ZPAYMENT_C60-PAYMENT_ID
* | [--->] IV_VERIFIER                    TYPE        ZPAYMENT_C60-VERIFIED_BY
* | [<-()] RS_RESULT                      TYPE        TY_RESULT
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD verify.
    DATA: ls_pay  TYPE zpayment_c60,
          ls_rcpt TYPE zreceipt_c60,
          lv_nr   TYPE n LENGTH 6,
          lv_rcpt TYPE c LENGTH 16,
          lv_paid TYPE zfee_details_c60-paid_amount,
          lv_bal  TYPE zfee_details_c60-balance.

    SELECT SINGLE * FROM zpayment_c60
      WHERE payment_id = @iv_payment_id
      INTO @ls_pay.
    IF sy-subrc <> 0.
      rs_result-message = 'Payment not found'.
      RETURN.
    ENDIF.
    IF ls_pay-status <> 'SUBMITTED'.
      rs_result-message =
        |Payment is { ls_pay-status }. Only SUBMITTED payments can be verified.|.
      RETURN.
    ENDIF.

    " Read the fee row first. Check it BEFORE using a receipt number.
    SELECT SINGLE paid_amount, balance FROM zfee_details_c60
      WHERE reg_no        = @ls_pay-reg_no
        AND academic_year = @ls_pay-academic_year
        AND fee_type      = @ls_pay-fee_type
      INTO @DATA(ls_fee).
    IF sy-subrc <> 0.
      rs_result-message = 'Fee record not found for this payment'.
      RETURN.
    ENDIF.

    " Two payments can be SUBMITTED at the same time, each one smaller than
    " the balance. Re-check against the balance as it is right now.
    IF ls_pay-amount > ls_fee-balance.
      rs_result-message =
        |Amount { ls_pay-amount } now exceeds balance { ls_fee-balance }. Reject this payment.|.
      RETURN.
    ENDIF.

    CALL FUNCTION 'NUMBER_GET_NEXT'
      EXPORTING nr_range_nr = '01'
                object      = 'ZNR_RCPT_C'
      IMPORTING number      = lv_nr
      EXCEPTIONS OTHERS     = 1.
    IF sy-subrc <> 0.
      rs_result-message = 'Could not generate receipt number'.
      RETURN.
    ENDIF.
    lv_rcpt = |FR/{ sy-datum(4) }/{ lv_nr }|.

    lv_paid = ls_fee-paid_amount + ls_pay-amount.
    lv_bal  = ls_fee-balance     - ls_pay-amount.

    " From here on everything is ONE unit: all saved, or all undone.
    UPDATE zfee_details_c60
      SET paid_amount = @lv_paid,
          balance     = @lv_bal
      WHERE reg_no        = @ls_pay-reg_no
        AND academic_year = @ls_pay-academic_year
        AND fee_type      = @ls_pay-fee_type.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      rs_result-message = 'Balance update failed'.
      RETURN.
    ENDIF.

    UPDATE zpayment_c60
      SET status      = 'VERIFIED',
          receipt_no  = @lv_rcpt,
          verified_by = @iv_verifier,
          verified_on = @sy-datum
      WHERE payment_id = @iv_payment_id.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      rs_result-message = 'Payment status update failed'.
      RETURN.
    ENDIF.

    ls_rcpt-receipt_no  = lv_rcpt.
    ls_rcpt-pay_id      = iv_payment_id.
    ls_rcpt-issued_on   = sy-datum.
    ls_rcpt-issued_by   = iv_verifier.
    ls_rcpt-print_count = 0.
    ls_rcpt-cancelled   = space.
    INSERT zreceipt_c60 FROM @ls_rcpt.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      rs_result-message = 'Receipt could not be saved'.
      RETURN.
    ENDIF.

    DATA ls_log TYPE zaudit_log_c60.
    SELECT MAX( log_id ) FROM zaudit_log_c60 INTO @DATA(lv_max).
    ls_log-log_id     = lv_max + 1.
    ls_log-user_id    = iv_verifier.
    ls_log-action     = 'VERIFY'.
    ls_log-object_key = lv_rcpt.
    GET TIME STAMP FIELD ls_log-logged_at.
    ls_log-remark     = |Payment { iv_payment_id } verified|.
    INSERT zaudit_log_c60 FROM @ls_log.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      rs_result-message = 'Audit log could not be written'.
      RETURN.
    ENDIF.

    COMMIT WORK.

    rs_result-ok         = abap_true.
    rs_result-receipt_no = lv_rcpt.
    rs_result-message    = |Payment verified. Receipt: { lv_rcpt }|.
  ENDMETHOD.
ENDCLASS.
