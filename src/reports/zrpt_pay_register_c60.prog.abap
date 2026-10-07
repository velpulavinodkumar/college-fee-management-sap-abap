*&---------------------------------------------------------------------*
*& Report ZRPT_PAY_REGISTER_C60
*& Step 18 - Report 1: PAYMENT REGISTER (ALV)
*& Shows every payment (SUBMITTED / VERIFIED / REJECTED) with filters
*&---------------------------------------------------------------------*
REPORT zrpt_pay_register_c60.

TABLES: zpayment_c60.

SELECT-OPTIONS: s_reg  FOR zpayment_c60-reg_no,
                s_date FOR zpayment_c60-payment_date,
                s_stat FOR zpayment_c60-status,
                s_type FOR zpayment_c60-fee_type,
                s_mode FOR zpayment_c60-payment_mode.

DATA: gt_pay TYPE STANDARD TABLE OF zcds_fee_pay,
      go_alv TYPE REF TO cl_salv_table.

*---------------------------------------------------------------------*
* Proper names for the selection screen fields
*---------------------------------------------------------------------*
INITIALIZATION.
  %_s_reg_%_app_%-text = 'Register No.'.
  %_s_date_%_app_%-text = 'Payment Date'.
  %_s_stat_%_app_%-text = 'Status'.
  %_s_type_%_app_%-text = 'Fee Type'.
  %_s_mode_%_app_%-text = 'Payment Mode'.

START-OF-SELECTION.

  SELECT * FROM zcds_fee_pay
    WHERE reg_no       IN @s_reg
      AND payment_date IN @s_date
      AND status       IN @s_stat
      AND fee_type     IN @s_type
      AND payment_mode IN @s_mode
    ORDER BY payment_date DESCENDING, payment_id DESCENDING
    INTO TABLE @gt_pay.

  IF gt_pay IS INITIAL.
    MESSAGE 'No payments found for the selection' TYPE 'S' DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = go_alv
        CHANGING  t_table      = gt_pay ).

      go_alv->get_functions( )->set_all( abap_true ).
      go_alv->get_display_settings( )->set_list_header( 'Payment Register' ).
      go_alv->get_display_settings( )->set_striped_pattern( abap_true ).
      go_alv->get_columns( )->set_optimize( abap_true ).

      " hide the fee-demand columns - they belong to other reports
      DATA(lo_cols) = go_alv->get_columns( ).
      DATA(lt_hide) = VALUE string_table( ( `FEECURRENCY` ) ( `TOTALFEE` )
                        ( `CONCESSION` ) ( `LATEFEE` ) ( `PAIDAMOUNT` )
                        ( `BALANCE` ) ( `DUE_DATE` ) ( `CANCELLED` ) ).
      LOOP AT lt_hide INTO DATA(lv_hide).
        TRY.
            lo_cols->get_column( CONV #( lv_hide ) )->set_visible( abap_false ).
          CATCH cx_salv_not_found.
        ENDTRY.
      ENDLOOP.

      " total of Amount
      TRY.
          go_alv->get_aggregations( )->add_aggregation(
            columnname = 'AMOUNT' ).
        CATCH cx_salv_not_found cx_salv_data_error cx_salv_existing.
      ENDTRY.

      go_alv->display( ).

    CATCH cx_salv_msg INTO DATA(lx_msg).
      MESSAGE lx_msg->get_text( ) TYPE 'E'.
  ENDTRY.
