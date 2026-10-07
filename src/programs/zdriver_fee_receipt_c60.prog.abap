*&---------------------------------------------------------------------*
*& Report ZDRIVER_FEE_RECEIPT_C60
*&---------------------------------------------------------------------*
*& Step 16 - Prints the fee receipt (Smart Form ZSF_RECEIPT_C60)
*&
*&  1. Type a receipt number (example FR/2026/000010).
*&  2. Press Execute (F8).
*&     - Default: the print preview opens.
*&     - Tick "Save as PDF file": a Save dialog opens and the receipt
*&       is saved as a PDF on your computer.
*&  Every successful print or PDF adds 1 to PRINT_COUNT of the receipt
*&  and writes a PRINT / PDF line in the audit log (Step 20).
*&---------------------------------------------------------------------*
REPORT zdriver_fee_receipt_c60.

PARAMETERS: p_rec TYPE zpayment_c60-receipt_no OBLIGATORY,
            p_pdf AS CHECKBOX.

DATA: ls_payment   TYPE zpayment_c60,
      ls_student   TYPE zstudent_cs60,
      ls_fee       TYPE zfee_details_c60,
      ls_receipt   TYPE zreceipt_c60,
      ls_smartform TYPE zst_fee_103,
      lv_year      TYPE zfee_details_c60-academic_year,
      lv_fm_name   TYPE rs38l_fnam,
      lv_ok        TYPE abap_bool.

INITIALIZATION.
  %_p_rec_%_app_%-text = 'Receipt No.'.
  %_p_pdf_%_app_%-text = 'Save as PDF file'.

START-OF-SELECTION.

  "1. The payment of this receipt
  SELECT SINGLE * FROM zpayment_c60
    WHERE receipt_no = @p_rec
    INTO @ls_payment.
  IF sy-subrc <> 0.
    MESSAGE 'Receipt number not found' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  "2. The student
  SELECT SINGLE * FROM zstudent_cs60
    WHERE reg_no = @ls_payment-reg_no
    INTO @ls_student.
  IF sy-subrc <> 0.
    MESSAGE 'Student details not found' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  "3. The fee row of THIS payment (register no. + year + fee type)
  lv_year = ls_payment-academic_year.
  SELECT SINGLE * FROM zfee_details_c60
    WHERE reg_no        = @ls_payment-reg_no
      AND academic_year = @lv_year
      AND fee_type      = @ls_payment-fee_type
    INTO @ls_fee.
  IF sy-subrc <> 0.
    MESSAGE 'Fee details not found for this payment' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  "4. The receipt row (issue date)
  SELECT SINGLE * FROM zreceipt_c60
    WHERE receipt_no = @p_rec
    INTO @ls_receipt.

  "5. Fill the form structure
  CLEAR ls_smartform.
  ls_smartform-receipt_no     = ls_payment-receipt_no.
  ls_smartform-issued_on      = ls_receipt-issued_on.
  ls_smartform-reg_no         = ls_student-reg_no.
  ls_smartform-name           = ls_student-name.
  ls_smartform-course         = ls_student-course.
  ls_smartform-branch         = ls_student-branch.
  ls_smartform-study_year     = ls_student-studyyear.
  ls_smartform-academic_year  = ls_fee-academic_year.
  ls_smartform-fee_type       = ls_fee-fee_type.
  ls_smartform-currency       = ls_fee-currency.
  ls_smartform-total_fee      = ls_fee-total_fee.
  ls_smartform-concession     = ls_fee-concession.
  ls_smartform-late_fee       = ls_fee-late_fee.
  ls_smartform-paid_amount    = ls_fee-paid_amount.
  ls_smartform-balance        = ls_fee-balance.
  ls_smartform-amount         = ls_payment-amount.
  ls_smartform-transaction_id = ls_payment-transaction_id.
  ls_smartform-payment_mode   = ls_payment-payment_mode.
  ls_smartform-payment_date   = ls_payment-payment_date.
  ls_smartform-bank_name      = ls_payment-bank_name.
  ls_smartform-verified_by    = ls_payment-verified_by.
  ls_smartform-status         = ls_payment-status.

  "6. Find the function module of the form
  CALL FUNCTION 'SSF_FUNCTION_MODULE_NAME'
    EXPORTING
      formname           = 'ZSF_RECEIPT_C60'
    IMPORTING
      fm_name            = lv_fm_name
    EXCEPTIONS
      no_form            = 1
      no_function_module = 2
      OTHERS             = 3.
  IF sy-subrc <> 0.
    MESSAGE 'Smart Form ZSF_RECEIPT_C60 not found or not active' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  "7. Preview or PDF
  IF p_pdf = abap_true.
    PERFORM save_as_pdf CHANGING lv_ok.
  ELSE.
    PERFORM show_preview CHANGING lv_ok.
  ENDIF.

  "8. Count the print and write the audit log (one unit: both or none)
  IF lv_ok = abap_true.
    PERFORM count_and_log.
  ENDIF.

*----------------------------------------------------------------------*
* print_count + 1 and one line in the audit log
*----------------------------------------------------------------------*
FORM count_and_log.
  DATA: ls_log TYPE zaudit_log_c60,
        lv_max TYPE zaudit_log_c60-log_id.

  UPDATE zreceipt_c60
    SET print_count = print_count + 1
    WHERE receipt_no = @p_rec
      AND print_count < 255.

  SELECT MAX( log_id ) FROM zaudit_log_c60 INTO @lv_max.

  ls_log-log_id     = lv_max + 1.
  ls_log-user_id    = sy-uname.
  IF p_pdf = abap_true.
    ls_log-action   = 'PDF'.
  ELSE.
    ls_log-action   = 'PRINT'.
  ENDIF.
  ls_log-object_key = p_rec.
  GET TIME STAMP FIELD ls_log-logged_at.
  ls_log-remark     = |Receipt { p_rec } printed|.
  INSERT zaudit_log_c60 FROM @ls_log.
  IF sy-subrc <> 0.
    ROLLBACK WORK.
    MESSAGE 'Print was done, but the audit log could not be written' TYPE 'S' DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  COMMIT WORK.
ENDFORM.

*----------------------------------------------------------------------*
* Print preview on the screen
*----------------------------------------------------------------------*
FORM show_preview CHANGING cv_ok TYPE abap_bool.
  cv_ok = abap_false.
  CALL FUNCTION lv_fm_name
    EXPORTING
      is_fee           = ls_smartform
    EXCEPTIONS
      formatting_error = 1
      internal_error   = 2
      send_error       = 3
      user_canceled    = 4
      OTHERS           = 5.
  IF sy-subrc = 0.
    cv_ok = abap_true.
  ELSE.
    MESSAGE 'Error while generating the fee receipt' TYPE 'S' DISPLAY LIKE 'E'.
  ENDIF.
ENDFORM.

*----------------------------------------------------------------------*
* Receipt saved as a PDF file on the user's computer
*----------------------------------------------------------------------*
FORM save_as_pdf CHANGING cv_ok TYPE abap_bool.
  DATA: ls_ctrl     TYPE ssfctrlop,
        ls_out      TYPE ssfcompop,
        ls_job      TYPE ssfcrescl,
        lt_lines    TYPE STANDARD TABLE OF tline,
        lv_size     TYPE i,
        lv_name     TYPE string,
        lv_filename TYPE string,
        lv_path     TYPE string,
        lv_fullpath TYPE string,
        lv_action   TYPE i.

  cv_ok = abap_false.

  "a. Make the form (no screen, give the result back as OTF)
  ls_ctrl-no_dialog = abap_true.
  ls_ctrl-getotf    = abap_true.
  ls_ctrl-preview   = space.
  ls_out-tddest     = 'LOCL'.
  ls_out-tdnoprev   = abap_true.

  CALL FUNCTION lv_fm_name
    EXPORTING
      control_parameters = ls_ctrl
      output_options     = ls_out
      user_settings      = space
      is_fee             = ls_smartform
    IMPORTING
      job_output_info    = ls_job
    EXCEPTIONS
      formatting_error   = 1
      internal_error     = 2
      send_error         = 3
      user_canceled      = 4
      OTHERS             = 5.
  IF sy-subrc <> 0.
    MESSAGE 'Error while generating the fee receipt' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  "b. OTF -> PDF
  CALL FUNCTION 'CONVERT_OTF'
    EXPORTING
      format                = 'PDF'
    IMPORTING
      bin_filesize          = lv_size
    TABLES
      otf                   = ls_job-otfdata
      lines                 = lt_lines
    EXCEPTIONS
      err_max_linewidth     = 1
      err_format            = 2
      err_conv_not_possible = 3
      err_bad_otf           = 4
      OTHERS                = 5.
  IF sy-subrc <> 0.
    MESSAGE 'PDF could not be created' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  "c. Ask where to save (FR/2026/000010 -> FR_2026_000010.pdf)
  lv_name = p_rec.
  REPLACE ALL OCCURRENCES OF '/' IN lv_name WITH '_'.
  lv_name = |{ lv_name }.pdf|.

  cl_gui_frontend_services=>file_save_dialog(
    EXPORTING
      default_extension    = 'pdf'
      default_file_name    = lv_name
    CHANGING
      filename             = lv_filename
      path                 = lv_path
      fullpath             = lv_fullpath
      user_action          = lv_action
    EXCEPTIONS
      cntl_error           = 1
      error_no_gui         = 2
      not_supported_by_gui = 3
      OTHERS               = 4 ).
  IF sy-subrc <> 0 OR lv_action <> cl_gui_frontend_services=>action_ok.
    MESSAGE 'PDF was not saved' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  "d. Write the file
  CALL FUNCTION 'GUI_DOWNLOAD'
    EXPORTING
      bin_filesize = lv_size
      filename     = lv_fullpath
      filetype     = 'BIN'
    TABLES
      data_tab     = lt_lines
    EXCEPTIONS
      OTHERS       = 1.
  IF sy-subrc <> 0.
    MESSAGE 'PDF file could not be written' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  cv_ok = abap_true.
  MESSAGE |Receipt saved as { lv_fullpath }| TYPE 'S'.
ENDFORM.
