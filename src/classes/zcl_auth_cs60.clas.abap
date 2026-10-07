CLASS zcl_auth_cs60 DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_result,
             ok      TYPE abap_bool,
             message TYPE string,
             role    TYPE zusers_c60-role,
           END OF ty_result.

    TYPES: BEGIN OF ty_otp_result,
             ok      TYPE abap_bool,
             message TYPE string,
             otp     TYPE c LENGTH 6,
           END OF ty_otp_result.

    CLASS-METHODS:
      register IMPORTING iv_user_id  TYPE zusers_c60-user_id
                         iv_role     TYPE zusers_c60-role
                         iv_name     TYPE zusers_c60-name
                         iv_email    TYPE zusers_c60-email
                         iv_phone    TYPE zusers_c60-phone
                         iv_password TYPE string
                         iv_question TYPE zusers_c60-sec_question
                         iv_answer   TYPE string
                         iv_seed     TYPE abap_bool DEFAULT abap_false
               RETURNING VALUE(rs_result) TYPE ty_result,

      login    IMPORTING iv_user_id  TYPE zusers_c60-user_id
                         iv_password TYPE string
               RETURNING VALUE(rs_result) TYPE ty_result,

      request_reset IMPORTING iv_user_id TYPE zusers_c60-user_id
                              iv_answer  TYPE string
                    RETURNING VALUE(rs_result) TYPE ty_otp_result,

      reset_password IMPORTING iv_user_id      TYPE zusers_c60-user_id
                               iv_otp          TYPE string
                               iv_new_password TYPE string
                     RETURNING VALUE(rs_result) TYPE ty_result.

  PRIVATE SECTION.
    CLASS-METHODS hash IMPORTING iv_salt TYPE string
                                 iv_text TYPE string
                       RETURNING VALUE(rv_hash) TYPE string.
ENDCLASS.



CLASS ZCL_AUTH_CS60 IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Private Method ZCL_AUTH_CS60=>HASH
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_SALT                        TYPE        STRING
* | [--->] IV_TEXT                        TYPE        STRING
* | [<-()] RV_HASH                        TYPE        STRING
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD hash.
    DATA lv_hash TYPE string.
    TRY.
        cl_abap_message_digest=>calculate_hash_for_char(
          EXPORTING if_algorithm  = 'SHA256'
                    if_data       = |{ iv_salt }{ iv_text }|
          IMPORTING ef_hashstring = lv_hash ).
      CATCH cx_abap_message_digest.
        CLEAR lv_hash.
    ENDTRY.
    rv_hash = lv_hash.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_AUTH_CS60=>LOGIN
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_USER_ID                     TYPE        ZUSERS_C60-USER_ID
* | [--->] IV_PASSWORD                    TYPE        STRING
* | [<-()] RS_RESULT                      TYPE        TY_RESULT
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD login.
    DATA lv_ts TYPE timestamp.

    SELECT SINGLE * FROM zusers_c60
      WHERE user_id = @iv_user_id
      INTO @DATA(ls_user).
    IF sy-subrc <> 0.
      rs_result-message = 'Invalid user ID or password'.   " same text on purpose
      RETURN.
    ENDIF.

    CASE ls_user-status.
      WHEN 'PENDING'.
        rs_result-message = 'Account awaiting admin approval'.
        RETURN.
      WHEN 'LOCKED'.
        rs_result-message = 'Account locked. Contact the admin'.
        RETURN.
      WHEN 'REJECTED'.
        rs_result-message = 'Registration was rejected'.
        RETURN.
    ENDCASE.

    IF hash( iv_salt = |{ ls_user-salt }| iv_text = iv_password ) = ls_user-pwd_hash.
      GET TIME STAMP FIELD lv_ts.
      UPDATE zusers_c60
        SET failed_attempts = 0,
            last_login      = @lv_ts
        WHERE user_id = @iv_user_id.
      COMMIT WORK.
      rs_result-ok      = abap_true.
      rs_result-role    = ls_user-role.
      rs_result-message = 'Login successful'.
    ELSE.
      DATA(lv_fail) = ls_user-failed_attempts + 1.
      DATA(lv_status) = COND zusers_c60-status(
                          WHEN lv_fail >= 3 THEN 'LOCKED' ELSE ls_user-status ).
      UPDATE zusers_c60
        SET failed_attempts = @lv_fail,
            status          = @lv_status
        WHERE user_id = @iv_user_id.
      COMMIT WORK.
      rs_result-message = COND #( WHEN lv_fail >= 3
        THEN 'Too many attempts. Account locked'
        ELSE 'Invalid user ID or password' ).
    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_AUTH_CS60=>REGISTER
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_USER_ID                     TYPE        ZUSERS_C60-USER_ID
* | [--->] IV_ROLE                        TYPE        ZUSERS_C60-ROLE
* | [--->] IV_NAME                        TYPE        ZUSERS_C60-NAME
* | [--->] IV_EMAIL                       TYPE        ZUSERS_C60-EMAIL
* | [--->] IV_PHONE                       TYPE        ZUSERS_C60-PHONE
* | [--->] IV_PASSWORD                    TYPE        STRING
* | [--->] IV_QUESTION                    TYPE        ZUSERS_C60-SEC_QUESTION
* | [--->] IV_ANSWER                      TYPE        STRING
* | [--->] IV_SEED                        TYPE        ABAP_BOOL (default =ABAP_FALSE)
* | [<-()] RS_RESULT                      TYPE        TY_RESULT
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD register.
    " 0. Only the seed program may create admins
    IF iv_role = 'X' AND iv_seed = abap_false.
      rs_result-message = 'Admin accounts cannot be self-registered'.
      RETURN.
    ENDIF.
    IF iv_role <> 'S' AND iv_role <> 'A' AND iv_role <> 'X'.
      rs_result-message = 'Invalid role'.
      RETURN.
    ENDIF.

    " 1. Required fields
    IF iv_user_id IS INITIAL OR iv_name IS INITIAL OR iv_answer IS INITIAL.
      rs_result-message = 'Please fill all required fields'.
      RETURN.
    ENDIF.

    " 2. Password rule: 8+ characters, one letter, one digit
    IF strlen( iv_password ) < 8
       OR NOT matches( val = iv_password regex = '.*[A-Za-z].*' )
       OR NOT matches( val = iv_password regex = '.*[0-9].*' ).
      rs_result-message = 'Password needs 8+ characters with a letter and a digit'.
      RETURN.
    ENDIF.

    " 3. Duplicate user
    SELECT SINGLE user_id FROM zusers_c60
      WHERE user_id = @iv_user_id
      INTO @DATA(lv_dummy).
    IF sy-subrc = 0.
      rs_result-message = 'User already registered'.
      RETURN.
    ENDIF.

    " 4. Students must exist in the student master
    IF iv_role = 'S'.
      SELECT SINGLE reg_no FROM zstudent_cs60
        WHERE reg_no = @iv_user_id
        INTO @DATA(lv_reg).
      IF sy-subrc <> 0.
        rs_result-message = 'Register number not found in student records'.
        RETURN.
      ENDIF.
    ENDIF.

    " 5. Build and store the user
    DATA ls_user TYPE zusers_c60.
    ls_user-user_id = iv_user_id.
    ls_user-role    = iv_role.
    ls_user-name    = iv_name.
    ls_user-email   = iv_email.
    ls_user-phone   = iv_phone.
    TRY.
        ls_user-salt = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_uuid_error.
        ls_user-salt = |{ sy-datum }{ sy-uzeit }{ sy-uname }|.
    ENDTRY.
    ls_user-pwd_hash        = hash( iv_salt = |{ ls_user-salt }| iv_text = iv_password ).
    ls_user-sec_question    = iv_question.
    ls_user-sec_answer_hash = hash( iv_salt = |{ ls_user-salt }|
                                    iv_text = to_upper( iv_answer ) ).
    ls_user-status          = COND #( WHEN iv_role = 'A' THEN 'PENDING' ELSE 'ACTIVE' ).
    ls_user-created_on      = sy-datum.

    INSERT zusers_c60 FROM @ls_user.
    IF sy-subrc = 0.
      COMMIT WORK.
      rs_result-ok = abap_true.
      rs_result-message = COND #( WHEN iv_role = 'A'
        THEN 'Registered. Wait for admin approval before logging in'
        ELSE 'Registered successfully. You can log in now' ).
    ELSE.
      ROLLBACK WORK.
      rs_result-message = 'Registration failed'.
    ENDIF.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_AUTH_CS60=>REQUEST_RESET
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_USER_ID                     TYPE        ZUSERS_C60-USER_ID
* | [--->] IV_ANSWER                      TYPE        STRING
* | [<-()] RS_RESULT                      TYPE        TY_OTP_RESULT
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD request_reset.
    DATA: lv_otp TYPE n LENGTH 6,
          lv_now TYPE timestamp,
          lv_exp TYPE timestamp,
          lv_max TYPE n LENGTH 6,
          lv_req TYPE n LENGTH 6,
          ls_rst TYPE zpwd_reset_c60.

    " 1. User and security answer must match
    SELECT SINGLE * FROM zusers_c60
      WHERE user_id = @iv_user_id
      INTO @DATA(ls_user).
    IF sy-subrc <> 0
       OR hash( iv_salt = |{ ls_user-salt }| iv_text = to_upper( iv_answer ) )
          <> ls_user-sec_answer_hash.
      rs_result-message = 'User ID or security answer is incorrect'.
      RETURN.
    ENDIF.

    IF ls_user-status = 'PENDING' OR ls_user-status = 'REJECTED'.
      rs_result-message = 'This account is not active yet'.
      RETURN.
    ENDIF.

    " 2. Generate a 6-digit OTP
    TRY.
        lv_otp = cl_abap_random_int=>create( seed = cl_abap_random=>seed( )
                                             min  = 100000
                                             max  = 999999 )->get_next( ).
      CATCH cx_root.
        rs_result-message = 'Could not generate OTP'.
        RETURN.
    ENDTRY.

    " 3. Expiry = now + 10 minutes
    GET TIME STAMP FIELD lv_now.
    TRY.
        lv_exp = cl_abap_tstmp=>add( tstmp = lv_now secs = 600 ).
      CATCH cx_root.
        rs_result-message = 'Could not set OTP expiry'.
        RETURN.
    ENDTRY.

    " 4. Cancel older unused requests, then store the new one
    UPDATE zpwd_reset_c60 SET used = 'X'
      WHERE user_id = @iv_user_id AND used = @space.

    SELECT MAX( req_id ) FROM zpwd_reset_c60
      WHERE user_id = @iv_user_id
      INTO @lv_max.
    lv_req = lv_max + 1.

    ls_rst-user_id    = iv_user_id.
    ls_rst-req_id     = lv_req.
    ls_rst-otp_hash   = hash( iv_salt = |{ ls_user-salt }| iv_text = |{ lv_otp }| ).
    ls_rst-expires_at = lv_exp.
    ls_rst-used       = space.
    INSERT zpwd_reset_c60 FROM @ls_rst.
    IF sy-subrc <> 0.
      ROLLBACK WORK.
      rs_result-message = 'Could not create reset request'.
      RETURN.
    ENDIF.
    COMMIT WORK.

    " 5. Return the OTP (demo: shown on screen; production: email or SMS)
    rs_result-ok      = abap_true.
    rs_result-otp     = lv_otp.
    rs_result-message = 'OTP generated. It is valid for 10 minutes'.
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Static Public Method ZCL_AUTH_CS60=>RESET_PASSWORD
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_USER_ID                     TYPE        ZUSERS_C60-USER_ID
* | [--->] IV_OTP                         TYPE        STRING
* | [--->] IV_NEW_PASSWORD                TYPE        STRING
* | [<-()] RS_RESULT                      TYPE        TY_RESULT
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD reset_password.
    DATA lv_now TYPE timestamp.

    " 1. Password rule
    IF strlen( iv_new_password ) < 8
       OR NOT matches( val = iv_new_password regex = '.*[A-Za-z].*' )
       OR NOT matches( val = iv_new_password regex = '.*[0-9].*' ).
      rs_result-message = 'Password needs 8+ characters with a letter and a digit'.
      RETURN.
    ENDIF.

    " 2. User must exist
    SELECT SINGLE * FROM zusers_c60
      WHERE user_id = @iv_user_id
      INTO @DATA(ls_user).
    IF sy-subrc <> 0.
      rs_result-message = 'Invalid request'.
      RETURN.
    ENDIF.

    " 3. Latest unused reset request
    SELECT * FROM zpwd_reset_c60
      WHERE user_id = @iv_user_id AND used = @space
      ORDER BY req_id DESCENDING
      INTO TABLE @DATA(lt_rst)
      UP TO 1 ROWS.
    READ TABLE lt_rst INTO DATA(ls_rst) INDEX 1.
    IF sy-subrc <> 0.
      rs_result-message = 'No active reset request. Request a new OTP'.
      RETURN.
    ENDIF.

    " 4. Expiry and OTP check
    GET TIME STAMP FIELD lv_now.
    IF lv_now > ls_rst-expires_at.
      rs_result-message = 'OTP expired. Request a new one'.
      RETURN.
    ENDIF.

    IF hash( iv_salt = |{ ls_user-salt }| iv_text = iv_otp ) <> ls_rst-otp_hash.
      rs_result-message = 'Incorrect OTP'.
      RETURN.
    ENDIF.

    " 5. Save the new password (same salt) and unlock the account
    DATA(lv_newhash) = hash( iv_salt = |{ ls_user-salt }| iv_text = iv_new_password ).
    UPDATE zusers_c60
      SET pwd_hash        = @lv_newhash,
          failed_attempts = 0,
          status          = 'ACTIVE'
      WHERE user_id = @iv_user_id.

    UPDATE zpwd_reset_c60 SET used = 'X'
      WHERE user_id = @iv_user_id AND req_id = @ls_rst-req_id.
    COMMIT WORK.

    rs_result-ok      = abap_true.
    rs_result-role    = ls_user-role.
    rs_result-message = 'Password changed. You can log in now'.
  ENDMETHOD.
ENDCLASS.