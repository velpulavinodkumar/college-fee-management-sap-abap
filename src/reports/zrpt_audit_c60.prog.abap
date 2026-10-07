*&---------------------------------------------------------------------*
*& Report ZRPT_AUDIT_C60
*& Step 20 - AUDIT LOG viewer (ALV)
*& Who verified / rejected which payment, and when
*&---------------------------------------------------------------------*
REPORT zrpt_audit_c60.

TABLES: zaudit_log_c60.

TYPES: BEGIN OF ty_log,
         log_id     TYPE zaudit_log_c60-log_id,
         log_date   TYPE d,
         log_time   TYPE t,
         user_id    TYPE zaudit_log_c60-user_id,
         action     TYPE zaudit_log_c60-action,
         object_key TYPE zaudit_log_c60-object_key,
         remark     TYPE zaudit_log_c60-remark,
       END OF ty_log.

SELECT-OPTIONS: s_user FOR zaudit_log_c60-user_id,
                s_act  FOR zaudit_log_c60-action,
                s_date FOR sy-datum.

DATA: gt_log TYPE STANDARD TABLE OF ty_log,
      go_alv TYPE REF TO cl_salv_table.

*---------------------------------------------------------------------*
* Proper names for the selection screen fields
*---------------------------------------------------------------------*
INITIALIZATION.
  %_s_user_%_app_%-text = 'User ID'.
  %_s_act_%_app_%-text  = 'Action (VERIFY / REJECT)'.
  %_s_date_%_app_%-text = 'Date'.

START-OF-SELECTION.

  DATA: ls_log TYPE ty_log,
        lv_tz  TYPE tznzone.

  IF sy-zonlo IS INITIAL.
    lv_tz = 'INDIA'.
  ELSE.
    lv_tz = sy-zonlo.
  ENDIF.

  SELECT log_id, logged_at, user_id, action, object_key, remark
    FROM zaudit_log_c60
    WHERE user_id IN @s_user
      AND action  IN @s_act
    ORDER BY log_id DESCENDING
    INTO TABLE @DATA(lt_raw).

  LOOP AT lt_raw INTO DATA(ls_raw).
    CLEAR ls_log.
    ls_log-log_id     = ls_raw-log_id.
    ls_log-user_id    = ls_raw-user_id.
    ls_log-action     = ls_raw-action.
    ls_log-object_key = ls_raw-object_key.
    ls_log-remark     = ls_raw-remark.
    CONVERT TIME STAMP ls_raw-logged_at TIME ZONE lv_tz
      INTO DATE ls_log-log_date TIME ls_log-log_time.
    IF ls_log-log_date IN s_date.
      APPEND ls_log TO gt_log.
    ENDIF.
  ENDLOOP.

  IF gt_log IS INITIAL.
    MESSAGE 'No audit log entries found for the selection' TYPE 'S' DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = go_alv
        CHANGING  t_table      = gt_log ).

      go_alv->get_functions( )->set_all( abap_true ).
      go_alv->get_display_settings( )->set_list_header( 'Audit Log' ).
      go_alv->get_display_settings( )->set_striped_pattern( abap_true ).

      DATA(lo_cols) = go_alv->get_columns( ).
      lo_cols->set_optimize( abap_true ).

      PERFORM head USING lo_cols 'LOG_ID'     'Log No.'.
      PERFORM head USING lo_cols 'LOG_DATE'   'Date'.
      PERFORM head USING lo_cols 'LOG_TIME'   'Time'.
      PERFORM head USING lo_cols 'USER_ID'    'Done By'.
      PERFORM head USING lo_cols 'ACTION'     'Action'.
      PERFORM head USING lo_cols 'OBJECT_KEY' 'Receipt / Payment No.'.
      PERFORM head USING lo_cols 'REMARK'     'Remark'.

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
    CATCH cx_salv_not_found.
  ENDTRY.
ENDFORM.
