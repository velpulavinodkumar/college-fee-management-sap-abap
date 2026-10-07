*&---------------------------------------------------------------------*
*& Report ZRPT_DAILY_COLL_C60
*& Step 18 - Report 3: DAILY COLLECTION (ALV)
*& VERIFIED payments only, per day and per payment mode
*&---------------------------------------------------------------------*
REPORT zrpt_daily_coll_c60.

TABLES: zpayment_c60.

TYPES: BEGIN OF ty_day,
         payment_date TYPE zpayment_c60-payment_date,
         payment_mode TYPE zpayment_c60-payment_mode,
         currency     TYPE zpayment_c60-currency,
         cnt          TYPE i,
         total        TYPE zpayment_c60-amount,
       END OF ty_day.

SELECT-OPTIONS: s_date FOR zpayment_c60-payment_date,
                s_mode FOR zpayment_c60-payment_mode.

DATA: gt_day TYPE STANDARD TABLE OF ty_day,
      go_alv TYPE REF TO cl_salv_table.

*---------------------------------------------------------------------*
* Proper names for the selection screen fields
*---------------------------------------------------------------------*
INITIALIZATION.
  %_s_date_%_app_%-text = 'Payment Date'.
  %_s_mode_%_app_%-text = 'Payment Mode'.

START-OF-SELECTION.

  SELECT payment_date, payment_mode, currency,
         COUNT( * ) AS cnt,
         SUM( amount ) AS total
    FROM zpayment_c60
    WHERE status = 'VERIFIED'
      AND payment_date IN @s_date
      AND payment_mode IN @s_mode
    GROUP BY payment_date, payment_mode, currency
    ORDER BY payment_date DESCENDING, payment_mode
    INTO CORRESPONDING FIELDS OF TABLE @gt_day.

  IF gt_day IS INITIAL.
    MESSAGE 'No verified payments found for the selection' TYPE 'S' DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = go_alv
        CHANGING  t_table      = gt_day ).

      go_alv->get_functions( )->set_all( abap_true ).
      go_alv->get_display_settings( )->set_list_header( 'Daily Fee Collection' ).
      go_alv->get_display_settings( )->set_striped_pattern( abap_true ).

      DATA(lo_cols) = go_alv->get_columns( ).
      lo_cols->set_optimize( abap_true ).

      PERFORM head USING lo_cols 'PAYMENT_DATE' 'Date'.
      PERFORM head USING lo_cols 'PAYMENT_MODE' 'Payment Mode'.
      PERFORM head USING lo_cols 'CURRENCY'     'Currency'.
      PERFORM head USING lo_cols 'CNT'          'No. of Payments'.
      PERFORM head USING lo_cols 'TOTAL'        'Amount Collected'.

      " grand totals
      DATA(lo_aggr) = go_alv->get_aggregations( ).
      TRY.
          lo_aggr->add_aggregation( columnname = 'CNT' ).
          lo_aggr->add_aggregation( columnname = 'TOTAL' ).
        CATCH cx_salv_not_found cx_salv_data_error cx_salv_existing.
      ENDTRY.

      " sub-total for every date
      TRY.
          go_alv->get_sorts( )->add_sort(
            columnname = 'PAYMENT_DATE'
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
      IF iv_name = 'TOTAL'.
        CAST cl_salv_column_table( lo_col )->set_currency_column( 'CURRENCY' ).
      ENDIF.
    CATCH cx_salv_not_found cx_salv_data_error.
  ENDTRY.
ENDFORM.
