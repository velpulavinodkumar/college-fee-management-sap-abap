*&---------------------------------------------------------------------*
*& Report ZFEE_DASH_C60
*& Step 19 - FEE DASHBOARD: key numbers + buttons to the 4 reports
*&---------------------------------------------------------------------*
REPORT zfee_dash_c60.

TABLES: sscrfields.

*---------------------------------------------------------------------*
* Screen layout
*---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE t_b1.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(32) l1.
    SELECTION-SCREEN COMMENT 35(25) v1.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(32) l2.
    SELECTION-SCREEN COMMENT 35(25) v2.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(32) l3.
    SELECTION-SCREEN COMMENT 35(25) v3.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(32) l4.
    SELECTION-SCREEN COMMENT 35(25) v4.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(32) l5.
    SELECTION-SCREEN COMMENT 35(25) v5.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(32) l6.
    SELECTION-SCREEN COMMENT 35(25) v6.
  SELECTION-SCREEN END OF LINE.
  SELECTION-SCREEN BEGIN OF LINE.
    SELECTION-SCREEN COMMENT 1(32) l7.
    SELECTION-SCREEN COMMENT 35(25) v7.
  SELECTION-SCREEN END OF LINE.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE t_b2.
  SELECTION-SCREEN PUSHBUTTON /1(40) b_reg  USER-COMMAND reg.
  SELECTION-SCREEN PUSHBUTTON /1(40) b_def  USER-COMMAND def.
  SELECTION-SCREEN PUSHBUTTON /1(40) b_day  USER-COMMAND day.
  SELECTION-SCREEN PUSHBUTTON /1(40) b_type USER-COMMAND typ.
SELECTION-SCREEN END OF BLOCK b2.

*---------------------------------------------------------------------*
* Texts of the screen, set once
*---------------------------------------------------------------------*
INITIALIZATION.
  t_b1   = 'Fee Collection Summary'.
  t_b2   = 'Reports'.
  l1     = 'Total fee demand'.
  l2     = 'Total collected'.
  l3     = 'Total balance'.
  l4     = '% collected'.
  l5     = 'Collected today (verified)'.
  l6     = 'Awaiting verification'.
  l7     = 'Overdue fee records'.
  b_reg  = 'Payment Register'.
  b_def  = 'Defaulters'.
  b_day  = 'Daily Collection'.
  b_type = 'Fee-Type-wise Collection'.

*---------------------------------------------------------------------*
* Numbers are re-read every time the screen is shown, so they are
* fresh again after coming back from a report
*---------------------------------------------------------------------*
AT SELECTION-SCREEN OUTPUT.
  PERFORM load_numbers.

*---------------------------------------------------------------------*
* Button clicks
*---------------------------------------------------------------------*
AT SELECTION-SCREEN.
  CASE sscrfields-ucomm.
    WHEN 'REG'.
      SUBMIT zrpt_pay_register_c60 VIA SELECTION-SCREEN AND RETURN.
    WHEN 'DEF'.
      SUBMIT zrpt_defaulters_c60 VIA SELECTION-SCREEN AND RETURN.
    WHEN 'DAY'.
      SUBMIT zrpt_daily_coll_c60 VIA SELECTION-SCREEN AND RETURN.
    WHEN 'TYP'.
      SUBMIT zrpt_feetype_coll_c60 VIA SELECTION-SCREEN AND RETURN.
  ENDCASE.

START-OF-SELECTION.
  " nothing to do - everything happens on the screen

*---------------------------------------------------------------------*
FORM load_numbers.
  DATA: lv_demand TYPE p LENGTH 15 DECIMALS 2,
        lv_paid   TYPE p LENGTH 15 DECIMALS 2,
        lv_bal    TYPE p LENGTH 15 DECIMALS 2,
        lv_today  TYPE p LENGTH 15 DECIMALS 2,
        lv_pct    TYPE p LENGTH 7  DECIMALS 2,
        lv_pend   TYPE i,
        lv_over   TYPE i.

  SELECT SUM( total_fee ), SUM( paid_amount ), SUM( balance )
    FROM zfee_details_c60
    INTO ( @lv_demand, @lv_paid, @lv_bal ).

  SELECT SUM( amount )
    FROM zpayment_c60
    WHERE status = 'VERIFIED' AND payment_date = @sy-datum
    INTO @lv_today.

  SELECT COUNT( * )
    FROM zpayment_c60
    WHERE status = 'SUBMITTED'
    INTO @lv_pend.

  SELECT COUNT( * )
    FROM zfee_details_c60
    WHERE balance > 0
      AND due_date <> '00000000'
      AND due_date < @sy-datum
    INTO @lv_over.

  IF lv_demand > 0.
    lv_pct = lv_paid * 100 / lv_demand.
  ENDIF.

  v1 = |{ lv_demand CURRENCY = 'INR' } INR|.
  v2 = |{ lv_paid   CURRENCY = 'INR' } INR|.
  v3 = |{ lv_bal    CURRENCY = 'INR' } INR|.
  v4 = |{ lv_pct DECIMALS = 2 } %|.
  v5 = |{ lv_today  CURRENCY = 'INR' } INR|.
  v6 = |{ lv_pend }|.
  v7 = |{ lv_over }|.
ENDFORM.
