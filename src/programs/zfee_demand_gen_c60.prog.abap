*&---------------------------------------------------------------------*
*& Report ZFEE_DEMAND_GEN_C60
*&---------------------------------------------------------------------*
*& Step 9 - Fee demand generation (Accountant)
*&
*& Reads the fee price list (ZFEE_STRUCT_CS60) and creates one row in
*& ZFEE_DETAILS_C60 per student per fee type.
*&
*&  - Test run (default) shows a preview and saves nothing.
*&  - Rows that already exist are skipped and never overwritten, so the
*&    program can be run again safely (idempotent) and paid amounts are
*&    never touched.
*&  - Rows are inserted one by one, so one duplicate never stops the
*&    whole batch.
*&---------------------------------------------------------------------*
REPORT zfee_demand_gen_c60.

*----------------------------------------------------------------------*
* Types
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_out,                      " one line in the result ALV
         status    TYPE c LENGTH 20,
         reg_no    TYPE zstudent_cs60-reg_no,
         name      TYPE zstudent_cs60-name,
         course    TYPE zstudent_cs60-course,
         branch    TYPE zstudent_cs60-branch,
         studyyear TYPE zstudent_cs60-studyyear,
         fee_type  TYPE zfee_details_c60-fee_type,
         total_fee TYPE zfee_details_c60-total_fee,
         currency  TYPE zfee_details_c60-currency,
         due_date  TYPE zfee_details_c60-due_date,
       END OF ty_out.

TYPES: BEGIN OF ty_key,                      " primary key of a demand row
         reg_no        TYPE zfee_details_c60-reg_no,
         academic_year TYPE zfee_details_c60-academic_year,
         fee_type      TYPE zfee_details_c60-fee_type,
       END OF ty_key.

*----------------------------------------------------------------------*
* Data
*----------------------------------------------------------------------*
DATA: gs_stu_sel   TYPE zstudent_cs60,       " only used to type the
      gs_fs_sel    TYPE zfee_struct_cs60,    " select-options below
      gt_out       TYPE STANDARD TABLE OF ty_out,
      gt_existing  TYPE SORTED TABLE OF ty_key
                   WITH UNIQUE KEY reg_no academic_year fee_type,
      gs_demand    TYPE zfee_details_c60,
      gv_found     TYPE abap_bool,
      gv_to_create TYPE i,
      gv_created   TYPE i,
      gv_skipped   TYPE i,
      gv_failed    TYPE i,
      gv_no_fs     TYPE i,
      gv_header    TYPE string.

*----------------------------------------------------------------------*
* Selection screen
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.  " Students
  SELECT-OPTIONS: s_course FOR gs_stu_sel-course LOWER CASE,
                  s_branch FOR gs_stu_sel-branch,
                  s_year   FOR gs_stu_sel-studyyear,
                  s_regno  FOR gs_stu_sel-reg_no.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.  " Fee types
  SELECT-OPTIONS s_ftype FOR gs_fs_sel-fee_type LOWER CASE.
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-003.  " Run mode
  PARAMETERS p_test AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b3.

*----------------------------------------------------------------------*
START-OF-SELECTION.
*----------------------------------------------------------------------*

  "1. Students that match the filters
  SELECT reg_no, name, course, branch, studyyear
    FROM zstudent_cs60
    WHERE course    IN @s_course
      AND branch    IN @s_branch
      AND studyyear IN @s_year
      AND reg_no    IN @s_regno
    ORDER BY reg_no
    INTO TABLE @DATA(lt_students).

  IF lt_students IS INITIAL.
    MESSAGE 'No students match the selection' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  "2. Price-list rows that match the filters
  SELECT course, branch, studyyear, fee_type, amount, currency, due_date
    FROM zfee_struct_cs60
    WHERE course    IN @s_course
      AND branch    IN @s_branch
      AND studyyear IN @s_year
      AND fee_type  IN @s_ftype
    INTO TABLE @DATA(lt_struct).

  IF lt_struct IS INITIAL.
    MESSAGE 'No fee structure rows match the selection' TYPE 'S' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  "3. Demand rows that already exist for these students
  "   (one database read for all students, not one read per row)
  SELECT reg_no, academic_year, fee_type
    FROM zfee_details_c60
    FOR ALL ENTRIES IN @lt_students
    WHERE reg_no = @lt_students-reg_no
    INTO TABLE @gt_existing.

  "4. One demand row per student per matching fee type
  LOOP AT lt_students INTO DATA(ls_stu).

    gv_found = abap_false.

    LOOP AT lt_struct INTO DATA(ls_fs)
         WHERE course    = ls_stu-course
           AND branch    = ls_stu-branch
           AND studyyear = ls_stu-studyyear.

      gv_found = abap_true.

      CLEAR gs_demand.
      gs_demand-reg_no        = ls_stu-reg_no.
      gs_demand-academic_year = ls_stu-studyyear.  " year of study, 1-4
      gs_demand-fee_type      = ls_fs-fee_type.
      gs_demand-total_fee     = ls_fs-amount.
      gs_demand-concession    = 0.
      gs_demand-late_fee      = 0.
      gs_demand-paid_amount   = 0.
      " Balance = Total - Concession + Late fee - Paid
      gs_demand-balance       = gs_demand-total_fee - gs_demand-concession
                              + gs_demand-late_fee  - gs_demand-paid_amount.
      gs_demand-currency      = ls_fs-currency.
      gs_demand-due_date      = ls_fs-due_date.
      gs_demand-course        = ls_stu-course.     " Delete these 3 lines if
      gs_demand-branch        = ls_stu-branch.     " your ZFEE_DETAILS_C60 has no
      gs_demand-studyyear     = ls_stu-studyyear.  " COURSE/BRANCH/STUDYYEAR

      APPEND VALUE #( reg_no    = ls_stu-reg_no
                      name      = ls_stu-name
                      course    = ls_stu-course
                      branch    = ls_stu-branch
                      studyyear = ls_stu-studyyear
                      fee_type  = ls_fs-fee_type
                      total_fee = ls_fs-amount
                      currency  = ls_fs-currency
                      due_date  = ls_fs-due_date )
             TO gt_out ASSIGNING FIELD-SYMBOL(<ls_out>).

      " Already generated earlier? Skip it, never overwrite it.
      IF line_exists( gt_existing[ reg_no        = gs_demand-reg_no
                                   academic_year = gs_demand-academic_year
                                   fee_type      = gs_demand-fee_type ] ).
        <ls_out>-status = 'EXISTS - SKIPPED'.
        gv_skipped = gv_skipped + 1.
        CONTINUE.
      ENDIF.

      IF p_test = abap_true.
        <ls_out>-status = 'WILL BE CREATED'.
        gv_to_create = gv_to_create + 1.
      ELSE.
        " Row-by-row insert: a duplicate returns sy-subrc = 4 instead of
        " dumping, so the rest of the batch is still saved.
        INSERT zfee_details_c60 FROM @gs_demand.
        IF sy-subrc = 0.
          <ls_out>-status = 'CREATED'.
          gv_created = gv_created + 1.
        ELSE.
          <ls_out>-status = 'FAILED - DUPLICATE'.
          gv_failed = gv_failed + 1.
        ENDIF.
      ENDIF.

    ENDLOOP.

    " Student has no price-list row for their course/branch/year
    IF gv_found = abap_false.
      APPEND VALUE #( status    = 'NO FEE STRUCTURE'
                      reg_no    = ls_stu-reg_no
                      name      = ls_stu-name
                      course    = ls_stu-course
                      branch    = ls_stu-branch
                      studyyear = ls_stu-studyyear ) TO gt_out.
      gv_no_fs = gv_no_fs + 1.
    ENDIF.

  ENDLOOP.

  "5. Save (only in a real run)
  IF p_test = abap_false.
    COMMIT WORK.
  ENDIF.

  "6. Show the result
  SORT gt_out BY reg_no fee_type.

  IF p_test = abap_true.
    gv_header = |TEST RUN - To create: { gv_to_create }  Exist: { gv_skipped }  | &&
                |No fee structure: { gv_no_fs }|.
  ELSE.
    gv_header = |SAVED - Created: { gv_created }  Skipped: { gv_skipped }  | &&
                |Failed: { gv_failed }  No fee structure: { gv_no_fs }|.
  ENDIF.

  TRY.
      cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_alv)
                              CHANGING  t_table      = gt_out ).
    CATCH cx_salv_msg.
      MESSAGE 'Result list could not be displayed' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
  ENDTRY.

  lo_alv->get_functions( )->set_all( abap_true ).
  lo_alv->get_columns( )->set_optimize( abap_true ).
  lo_alv->get_display_settings( )->set_striped_pattern( abap_true ).
  lo_alv->get_display_settings( )->set_list_header( CONV #( gv_header ) ).

  TRY.
      lo_alv->get_columns( )->get_column( 'TOTAL_FEE' )->set_currency_column( 'CURRENCY' ).
      lo_alv->get_columns( )->get_column( 'STATUS' )->set_long_text( 'Result' ).
      lo_alv->get_columns( )->get_column( 'STATUS' )->set_medium_text( 'Result' ).
      lo_alv->get_columns( )->get_column( 'STATUS' )->set_short_text( 'Result' ).
    CATCH cx_salv_not_found cx_salv_data_error.
      " Column names are fixed in TY_OUT, so this cannot normally happen
  ENDTRY.

  MESSAGE gv_header TYPE 'S'.
  lo_alv->display( ).
