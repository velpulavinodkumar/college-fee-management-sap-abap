*&---------------------------------------------------------------------*
*& Report ZRPT_DEFAULTERS_C60
*& Step 18 - Report 2: DEFAULTERS (ALV)
*& Students whose balance is still unpaid after the due date
*&---------------------------------------------------------------------*
REPORT zrpt_defaulters_c60.

TABLES: zstudent_cs60.

TYPES: BEGIN OF ty_def,
         reg_no      TYPE zfee_details_c60-reg_no,
         name        TYPE zstudent_cs60-name,
         branch      TYPE zstudent_cs60-branch,
         studyyear   TYPE zstudent_cs60-studyyear,
         phone       TYPE zstudent_cs60-phone,
         email       TYPE zstudent_cs60-email,
         fee_type    TYPE zfee_details_c60-fee_type,
         currency    TYPE zfee_details_c60-currency,
         total_fee   TYPE zfee_details_c60-total_fee,
         concession  TYPE zfee_details_c60-concession,
         late_fee    TYPE zfee_details_c60-late_fee,
         paid_amount TYPE zfee_details_c60-paid_amount,
         balance     TYPE zfee_details_c60-balance,
         due_date    TYPE zfee_details_c60-due_date,
         days_late   TYPE i,
       END OF ty_def.

SELECT-OPTIONS: s_reg FOR zstudent_cs60-reg_no,
                s_br  FOR zstudent_cs60-branch,
                s_yr  FOR zstudent_cs60-studyyear.
PARAMETERS:     p_asof TYPE d DEFAULT sy-datum,
                p_all  AS CHECKBOX.   " also show balances not yet due

DATA: gt_def TYPE STANDARD TABLE OF ty_def,
      go_alv TYPE REF TO cl_salv_table.

*---------------------------------------------------------------------*
* Proper names for the selection screen fields
*---------------------------------------------------------------------*
INITIALIZATION.
  %_s_reg_%_app_%-text = 'Register No.'.
  %_s_br_%_app_%-text = 'Branch'.
  %_s_yr_%_app_%-text = 'Year of Study'.
  %_p_asof_%_app_%-text = 'Overdue as on date'.
  %_p_all_%_app_%-text = 'Show not-yet-due balances'.

START-OF-SELECTION.

  SELECT f~reg_no, s~name, s~branch, s~studyyear, s~phone, s~email,
         f~fee_type, f~currency, f~total_fee, f~concession, f~late_fee,
         f~paid_amount, f~balance, f~due_date
    FROM zfee_details_c60 AS f
    INNER JOIN zstudent_cs60 AS s ON s~reg_no = f~reg_no
    WHERE f~reg_no IN @s_reg
      AND s~branch IN @s_br
      AND s~studyyear IN @s_yr
      AND f~balance > 0
    INTO CORRESPONDING FIELDS OF TABLE @gt_def.

  " days overdue; drop rows not yet due (unless the checkbox is ticked)
  LOOP AT gt_def ASSIGNING FIELD-SYMBOL(<ls_def>).
    IF <ls_def>-due_date IS NOT INITIAL AND <ls_def>-due_date < p_asof.
      <ls_def>-days_late = p_asof - <ls_def>-due_date.
    ENDIF.
  ENDLOOP.

  IF p_all IS INITIAL.
    DELETE gt_def WHERE days_late <= 0.
  ENDIF.

  IF gt_def IS INITIAL.
    MESSAGE 'No defaulters found - nobody is overdue' TYPE 'S'.
    RETURN.
  ENDIF.

  SORT gt_def BY days_late DESCENDING reg_no.

  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = go_alv
        CHANGING  t_table      = gt_def ).

      go_alv->get_functions( )->set_all( abap_true ).
      go_alv->get_display_settings( )->set_list_header( 'Fee Defaulters' ).
      go_alv->get_display_settings( )->set_striped_pattern( abap_true ).

      DATA(lo_cols) = go_alv->get_columns( ).
      lo_cols->set_optimize( abap_true ).

      PERFORM head USING lo_cols 'REG_NO'      'Reg. No.'.
      PERFORM head USING lo_cols 'NAME'        'Student Name'.
      PERFORM head USING lo_cols 'BRANCH'      'Branch'.
      PERFORM head USING lo_cols 'STUDYYEAR'   'Year'.
      PERFORM head USING lo_cols 'PHONE'       'Phone'.
      PERFORM head USING lo_cols 'EMAIL'       'E-mail'.
      PERFORM head USING lo_cols 'FEE_TYPE'    'Fee Type'.
      PERFORM head USING lo_cols 'CURRENCY'    'Currency'.
      PERFORM head USING lo_cols 'TOTAL_FEE'   'Total Fee'.
      PERFORM head USING lo_cols 'CONCESSION'  'Concession'.
      PERFORM head USING lo_cols 'LATE_FEE'    'Late Fee'.
      PERFORM head USING lo_cols 'PAID_AMOUNT' 'Paid'.
      PERFORM head USING lo_cols 'BALANCE'     'Balance Due'.
      PERFORM head USING lo_cols 'DUE_DATE'    'Due Date'.
      PERFORM head USING lo_cols 'DAYS_LATE'   'Days Overdue'.

      " total of the balance
      TRY.
          go_alv->get_aggregations( )->add_aggregation( columnname = 'BALANCE' ).
        CATCH cx_salv_not_found cx_salv_data_error cx_salv_existing.
      ENDTRY.

      go_alv->display( ).

    CATCH cx_salv_msg INTO DATA(lx_msg).
      MESSAGE lx_msg->get_text( ) TYPE 'E'.
  ENDTRY.

*---------------------------------------------------------------------*
* heading text + currency reference for one column
*---------------------------------------------------------------------*
FORM head USING io_cols TYPE REF TO cl_salv_columns_table
                iv_name TYPE lvc_fname
                iv_text TYPE csequence.
  DATA lv_l TYPE scrtext_l.
  DATA lv_m TYPE scrtext_m.
  DATA lv_s TYPE scrtext_s.
  lv_l = iv_text.
  lv_m = iv_text.
  lv_s = iv_text.
  TRY.
      DATA(lo_col) = io_cols->get_column( iv_name ).
      lo_col->set_long_text( lv_l ).
      lo_col->set_medium_text( lv_m ).
      lo_col->set_short_text( lv_s ).
      CASE iv_name.
        WHEN 'TOTAL_FEE' OR 'CONCESSION' OR 'LATE_FEE'
          OR 'PAID_AMOUNT' OR 'BALANCE'.
          CAST cl_salv_column_table( lo_col )->set_currency_column( 'CURRENCY' ).
      ENDCASE.
    CATCH cx_salv_not_found cx_salv_data_error.
  ENDTRY.
ENDFORM.
