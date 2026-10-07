*&---------------------------------------------------------------------*
*& Report ZRPT_FEETYPE_COLL_C60
*& Step 18 - Report 4: FEE-TYPE-WISE COLLECTION (ALV)
*& Per fee type and branch: demand, collected, balance, % collected
*&---------------------------------------------------------------------*
REPORT zrpt_feetype_coll_c60.

TABLES: zfee_details_c60, zstudent_cs60.

TYPES: BEGIN OF ty_ft,
         fee_type    TYPE zfee_details_c60-fee_type,
         branch      TYPE zstudent_cs60-branch,
         currency    TYPE zfee_details_c60-currency,
         students    TYPE i,
         total_fee   TYPE zfee_details_c60-total_fee,
         concession  TYPE zfee_details_c60-concession,
         paid_amount TYPE zfee_details_c60-paid_amount,
         balance     TYPE zfee_details_c60-balance,
         pct         TYPE p LENGTH 5 DECIMALS 2,
       END OF ty_ft.

SELECT-OPTIONS: s_type FOR zfee_details_c60-fee_type,
                s_br   FOR zstudent_cs60-branch,
                s_yr   FOR zstudent_cs60-studyyear.

DATA: gt_ft  TYPE STANDARD TABLE OF ty_ft,
      go_alv TYPE REF TO cl_salv_table.

*---------------------------------------------------------------------*
* Proper names for the selection screen fields
*---------------------------------------------------------------------*
INITIALIZATION.
  %_s_type_%_app_%-text = 'Fee Type'.
  %_s_br_%_app_%-text = 'Branch'.
  %_s_yr_%_app_%-text = 'Year of Study'.

START-OF-SELECTION.

  SELECT f~fee_type, s~branch, f~currency,
         COUNT( * )          AS students,
         SUM( f~total_fee )   AS total_fee,
         SUM( f~concession )  AS concession,
         SUM( f~paid_amount ) AS paid_amount,
         SUM( f~balance )     AS balance
    FROM zfee_details_c60 AS f
    INNER JOIN zstudent_cs60 AS s ON s~reg_no = f~reg_no
    WHERE f~fee_type IN @s_type
      AND s~branch   IN @s_br
      AND s~studyyear IN @s_yr
    GROUP BY f~fee_type, s~branch, f~currency
    ORDER BY f~fee_type, s~branch
    INTO CORRESPONDING FIELDS OF TABLE @gt_ft.

  IF gt_ft IS INITIAL.
    MESSAGE 'No fee data found for the selection' TYPE 'S' DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  " percentage collected = paid / total fee
  LOOP AT gt_ft ASSIGNING FIELD-SYMBOL(<ls_ft>).
    IF <ls_ft>-total_fee > 0.
      <ls_ft>-pct = <ls_ft>-paid_amount * 100 / <ls_ft>-total_fee.
    ENDIF.
  ENDLOOP.

  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = go_alv
        CHANGING  t_table      = gt_ft ).

      go_alv->get_functions( )->set_all( abap_true ).
      go_alv->get_display_settings( )->set_list_header( 'Fee-Type-wise Collection' ).
      go_alv->get_display_settings( )->set_striped_pattern( abap_true ).

      DATA(lo_cols) = go_alv->get_columns( ).
      lo_cols->set_optimize( abap_true ).

      PERFORM head USING lo_cols 'FEE_TYPE'    'Fee Type'.
      PERFORM head USING lo_cols 'BRANCH'      'Branch'.
      PERFORM head USING lo_cols 'CURRENCY'    'Currency'.
      PERFORM head USING lo_cols 'STUDENTS'    'No. of Students'.
      PERFORM head USING lo_cols 'TOTAL_FEE'   'Total Demand'.
      PERFORM head USING lo_cols 'CONCESSION'  'Concession'.
      PERFORM head USING lo_cols 'PAID_AMOUNT' 'Collected'.
      PERFORM head USING lo_cols 'BALANCE'     'Balance'.
      PERFORM head USING lo_cols 'PCT'         '% Collected'.

      " grand totals (not for the percentage)
      DATA(lo_aggr) = go_alv->get_aggregations( ).
      TRY.
          lo_aggr->add_aggregation( columnname = 'STUDENTS' ).
          lo_aggr->add_aggregation( columnname = 'TOTAL_FEE' ).
          lo_aggr->add_aggregation( columnname = 'CONCESSION' ).
          lo_aggr->add_aggregation( columnname = 'PAID_AMOUNT' ).
          lo_aggr->add_aggregation( columnname = 'BALANCE' ).
        CATCH cx_salv_not_found cx_salv_data_error cx_salv_existing.
      ENDTRY.

      " sub-total for every fee type
      TRY.
          go_alv->get_sorts( )->add_sort(
            columnname = 'FEE_TYPE'
            subtotal   = abap_true ).
        CATCH cx_salv_not_found cx_salv_existing cx_salv_data_error.
      ENDTRY.

      go_alv->display( ).

    CATCH cx_salv_msg INTO DATA(lx_msg).
      MESSAGE lx_msg->get_text( ) TYPE 'E'.
  ENDTRY.

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
        WHEN 'TOTAL_FEE' OR 'CONCESSION' OR 'PAID_AMOUNT' OR 'BALANCE'.
          CAST cl_salv_column_table( lo_col )->set_currency_column( 'CURRENCY' ).
      ENDCASE.
    CATCH cx_salv_not_found cx_salv_data_error.
  ENDTRY.
ENDFORM.
