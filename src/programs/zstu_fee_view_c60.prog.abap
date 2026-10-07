*&---------------------------------------------------------------------*
*& Report ZSTU_FEE_VIEW_C60
*&---------------------------------------------------------------------*
*& Step 10 - Student fee view
*&
*&  - The user must log in first (same ZCL_AUTH_CS60 login as the app).
*&  - STUDENT  : always sees only his / her OWN fee rows. The register
*&               number is taken from the login, never from the screen,
*&               so one student can never see another student's data.
*&  - ACCOUNTANT / ADMIN : may enter any register number.
*&  - Status per row is derived: PAID / PARTIAL / UNPAID / OVERDUE.
*&---------------------------------------------------------------------*
REPORT zstu_fee_view_c60.

TYPES: BEGIN OF ty_out,
         light         TYPE c LENGTH 1,     " traffic light icon column
         fee_type      TYPE zfee_details_c60-fee_type,
         academic_year TYPE zfee_details_c60-academic_year,
         total_fee     TYPE zfee_details_c60-total_fee,
         concession    TYPE zfee_details_c60-concession,
         late_fee      TYPE zfee_details_c60-late_fee,
         paid_amount   TYPE zfee_details_c60-paid_amount,
         balance       TYPE zfee_details_c60-balance,
         currency      TYPE zfee_details_c60-currency,
         due_date      TYPE zfee_details_c60-due_date,
         status        TYPE c LENGTH 10,
       END OF ty_out.

DATA: gt_out    TYPE STANDARD TABLE OF ty_out,
      gv_role   TYPE zusers_c60-role,
      gv_regno  TYPE zstudent_cs60-reg_no,
      gv_header TYPE string.

*----------------------------------------------------------------------*
* Selection screen
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.   " Login
  PARAMETERS: p_user TYPE zusers_c60-user_id OBLIGATORY,
              p_pass TYPE c LENGTH 30 LOWER CASE OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.   " Staff only
  PARAMETERS p_reg TYPE zstudent_cs60-reg_no.
SELECTION-SCREEN END OF BLOCK b2.

AT SELECTION-SCREEN OUTPUT.
  LOOP AT SCREEN.
    IF screen-name = 'P_PASS'.
      screen-invisible = 1.                 " mask the password
      MODIFY SCREEN.
    ENDIF.
  ENDLOOP.

*----------------------------------------------------------------------*
START-OF-SELECTION.
*----------------------------------------------------------------------*

  "1. Log in
  DATA(ls_login) = zcl_auth_cs60=>login( iv_user_id  = p_user
                                         iv_password = CONV string( p_pass ) ).
  CLEAR p_pass.
  IF ls_login-ok = abap_false.
    MESSAGE ls_login-message TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
  gv_role = ls_login-role.

  "2. Decide whose fees to show
  CASE gv_role.
    WHEN 'S'.
      gv_regno = p_user.                     " student: own register number only
      IF p_reg IS NOT INITIAL AND p_reg <> p_user.
        MESSAGE 'Students can view only their own fees' TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
      ENDIF.
    WHEN 'A' OR 'X'.
      gv_regno = p_reg.
      IF gv_regno IS INITIAL.
        MESSAGE 'Enter the register number to view' TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
      ENDIF.
    WHEN OTHERS.
      MESSAGE 'Role not allowed' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
  ENDCASE.

  "3. Student master record
  SELECT SINGLE reg_no, name, course, branch, studyyear
    FROM zstudent_cs60
    WHERE reg_no = @gv_regno
    INTO @DATA(ls_stu).
  IF sy-subrc <> 0.
    MESSAGE 'Register number not found in student records' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  "4. Fee rows
  SELECT fee_type, academic_year, total_fee, concession, late_fee,
         paid_amount, balance, currency, due_date
    FROM zfee_details_c60
    WHERE reg_no = @gv_regno
    ORDER BY academic_year, fee_type
    INTO CORRESPONDING FIELDS OF TABLE @gt_out.

  IF gt_out IS INITIAL.
    MESSAGE 'No fee demand generated for this student yet' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  "5. Derive status and traffic light per row
  LOOP AT gt_out ASSIGNING FIELD-SYMBOL(<ls_out>).
    IF <ls_out>-balance <= 0.
      <ls_out>-status = 'PAID'.
      <ls_out>-light  = '3'.                             " green
    ELSEIF <ls_out>-paid_amount > 0.
      <ls_out>-status = 'PARTIAL'.
      <ls_out>-light  = '2'.                             " yellow
    ELSE.
      <ls_out>-status = 'UNPAID'.
      <ls_out>-light  = '1'.                             " red
    ENDIF.
    " Anything still owed after the due date is overdue
    IF <ls_out>-balance > 0 AND <ls_out>-due_date IS NOT INITIAL
       AND <ls_out>-due_date < sy-datum.
      <ls_out>-status = 'OVERDUE'.
      <ls_out>-light  = '1'.
    ENDIF.
  ENDLOOP.

  "6. Header text with totals (one currency assumed: INR)
  DATA(lv_total)   = REDUCE zfee_details_c60-total_fee(
                       INIT s = CONV zfee_details_c60-total_fee( 0 )
                       FOR r IN gt_out NEXT s = s + r-total_fee ).
  DATA(lv_paid)    = REDUCE zfee_details_c60-paid_amount(
                       INIT s = CONV zfee_details_c60-paid_amount( 0 )
                       FOR r IN gt_out NEXT s = s + r-paid_amount ).
  DATA(lv_balance) = REDUCE zfee_details_c60-balance(
                       INIT s = CONV zfee_details_c60-balance( 0 )
                       FOR r IN gt_out NEXT s = s + r-balance ).

  gv_header = |{ ls_stu-reg_no } { ls_stu-name } - { ls_stu-course } { ls_stu-branch } | &&
              |Year { ls_stu-studyyear } | &&
              |Total { lv_total CURRENCY = gt_out[ 1 ]-currency } | &&
              |Paid { lv_paid CURRENCY = gt_out[ 1 ]-currency } | &&
              |Balance { lv_balance CURRENCY = gt_out[ 1 ]-currency }|.

  "7. Show as ALV
  TRY.
      cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_alv)
                              CHANGING  t_table      = gt_out ).
    CATCH cx_salv_msg.
      MESSAGE 'Fee list could not be displayed' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
  ENDTRY.

  DATA(lo_cols) = lo_alv->get_columns( ).
  lo_cols->set_optimize( abap_true ).
  lo_cols->set_exception_column( 'LIGHT' ).
  lo_alv->get_functions( )->set_all( abap_true ).
  lo_alv->get_display_settings( )->set_striped_pattern( abap_true ).
  lo_alv->get_display_settings( )->set_list_header( CONV #( gv_header ) ).

  TRY.
      DATA(lt_cur_cols) = VALUE string_table( ( `TOTAL_FEE` ) ( `CONCESSION` )
                                              ( `LATE_FEE` ) ( `PAID_AMOUNT` ) ( `BALANCE` ) ).
      LOOP AT lt_cur_cols INTO DATA(lv_col).
        CAST cl_salv_column_table( lo_cols->get_column( CONV #( lv_col ) )
          )->set_currency_column( 'CURRENCY' ).
      ENDLOOP.
      lo_cols->get_column( 'CURRENCY' )->set_visible( abap_false ).
    CATCH cx_salv_not_found cx_salv_data_error.
      " Column names are fixed in TY_OUT, so this cannot normally happen
  ENDTRY.

  lo_alv->display( ).
