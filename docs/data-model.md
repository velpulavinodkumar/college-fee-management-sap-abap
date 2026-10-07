# Data model

Eight transparent tables, all client-dependent (first key field `MANDT`). Amount fields (`CURR 13,2`) reference the `CURRENCY` field (`CUKY 5`) of the same table. Foreign keys: `ZFEE_DETAILS_C60-REG_NO` and `ZPAYMENT_C60-REG_NO` point to `ZSTUDENT_CS60`.

## ZSTUDENT_CS60 - Student master

| Field | Data element | Type | Key |
| --- | --- | --- | --- |
| MANDT | MANDT | CLNT 3 | Yes |
| REG_NO | ZDE_REG_NO_C60 | CHAR 10 | Yes |
| NAME | ZDE_NAME_C60 | CHAR 30 | |
| BRANCH | ZDE_BRANCH_C60 | CHAR 10 | |
| STUDYYEAR | ZDE_YEAR_C60 | CHAR 1 | |
| PHONE | ZDE_PHONE_C60 | CHAR 10 | |
| COURSE | ZDE_COURSE_C60 | CHAR 10 | |
| EMAIL | ZDE_EMAIL_C60 | CHAR 60 | |

## ZFEE_STRUCT_CS60 - Fee price list

| Field | Data element | Type | Key |
| --- | --- | --- | --- |
| MANDT | MANDT | CLNT 3 | Yes |
| COURSE | ZDE_COURSE_C60 | CHAR 10 | Yes |
| BRANCH | ZDE_BRANCH_C60 | CHAR 10 | Yes |
| STUDYYEAR | ZDE_YEAR_C60 | CHAR 1 | Yes |
| FEE_TYPE | ZDE_FEE_TYPE_C60 | CHAR 20 | Yes |
| AMOUNT | ZDE_TOTAL_FEE_C60 | CURR 13,2 | |
| CURRENCY | ZDE_CURRENCY_C60 | CUKY 5 | |
| DUE_DATE | ZDE_DUEDATE_C60 | DATS 8 | |

## ZFEE_DETAILS_C60 - Fee demand per student

| Field | Data element | Type | Key |
| --- | --- | --- | --- |
| MANDT | MANDT | CLNT 3 | Yes |
| REG_NO | ZDE_REG_NO_C60 | CHAR 10 | Yes |
| ACADEMIC_YEAR | ZDE_ACAD_YEAR_C60 | CHAR 1 | Yes |
| FEE_TYPE | ZDE_FEE_TYPE_C60 | CHAR 20 | Yes |
| TOTAL_FEE | ZDE_TOTAL_FEE_C60 | CURR 13,2 | |
| PAID_AMOUNT | ZDE_PAID_AMOUNT_C60 | CURR 13,2 | |
| BALANCE | ZDE_BALANCE_C60 | CURR 13,2 | |
| CURRENCY | ZDE_CURRENCY_C60 | CUKY 5 | |
| DUE_DATE | ZDE_DUEDATE_C60 | DATS 8 | |
| CONCESSION | ZDE_CONCESSION_C60 | CURR 13,2 | |
| LATE_FEE | ZDE_BALANCE1_C60 | CURR 13,2 | |
| COURSE | ZDE_COURSE_C60 | CHAR 10 | |
| BRANCH | ZDE_BRANCH_C60 | CHAR 10 | |
| STUDYYEAR | ZDE_YEAR_C60 | CHAR 1 | |

Balance = Total fee - Concession + Late fee - Paid amount.

## ZPAYMENT_C60 - Payments

| Field | Data element | Type | Key |
| --- | --- | --- | --- |
| MANDT | MANDT | CLNT 3 | Yes |
| PAYMENT_ID | ZDE_PAY_ID_C60 | NUMC 10 | Yes |
| REG_NO | ZDE_REG_NO_C60 | CHAR 10 | Yes |
| TRANSACTION_ID | ZDE_TRANSACTION_ID_C60 | CHAR 30 | |
| CURRENCY | ZDE_CURRENCY_C60 | CUKY 5 | |
| AMOUNT | ZDEAMOUNT_C60 | CURR 13,2 | |
| PAYMENT_MODE | ZDEPAYMENT_MODE_C60 | CHAR 15 | |
| PAYMENT_DATE | ZDEPAYMENT_DATE_C60 | DATS 8 | |
| STATUS | ZDESTATUS_C60 | CHAR 15 | |
| ACADEMIC_YEAR | - | CHAR 9 (first character = year of study) | |
| FEE_TYPE | ZDE_FEE_TYPE_C60 | CHAR 20 | |
| BANK_NAME | ZDE_BANK_C60 | CHAR 30 | |
| ENTERED_BY | ZDE_USER_ID_C60 | CHAR 12 | |
| VERIFIED_BY | ZDE_USER_ID_C60 | CHAR 12 | |
| VERIFIED_ON | ZDE_DUEDATE_C60 | DATS 8 | |
| REMARK | ZDE_REMARK_C60 | CHAR 60 | |
| RECEIPT_NO | ZDE_RECEIPT_NO_C60 | CHAR 16 | |

Status values: `SUBMITTED`, `VERIFIED`, `REJECTED`.

## ZRECEIPT_C60 - Issued receipts

| Field | Data element | Type | Key |
| --- | --- | --- | --- |
| MANDT | MANDT | CLNT 3 | Yes |
| RECEIPT_NO | ZDE_RECEIPT_NO_C60 | CHAR 16 | Yes |
| PAY_ID | ZDE_PAY_ID_C60 | NUMC 10 | |
| ISSUED_BY | SYUNAME | CHAR 12 | |
| ISSUED_ON | SYDATUM | DATS 8 | |
| PRINT_COUNT | ZDE_PRINT_COUNT_C60 | INT1 | |
| CANCELLED | ZDE_CANCELLED_C60 | CHAR 1 | |

## ZUSERS_C60 - Application users

| Field | Data element | Type | Key |
| --- | --- | --- | --- |
| MANDT | MANDT | CLNT 3 | Yes |
| USER_ID | ZDE_USER_ID_C60 | CHAR 12 | Yes |
| ROLE | ZDE_ROLE_C60 | CHAR 1 (S / A / X) | |
| NAME | ZDE_NAME_C60 | CHAR 30 | |
| EMAIL | ZDE_EMAIL_C60 | CHAR 60 | |
| PHONE | ZDE_PHONE_C60 | CHAR 10 | |
| PWD_HASH | ZDE_HASH_C60 | CHAR 64 | |
| SALT | ZDE_SALT_C60 | CHAR 32 | |
| SEC_QUESTION | ZDE_SECQ_C60 | CHAR 60 | |
| SEC_ANSWER_HASH | ZDE_HASH_C60 | CHAR 64 | |
| STATUS | ZDE_USTATUS_C60 | CHAR 10 | |
| FAILED_ATTEMPTS | INT1 | INT1 | |
| LAST_LOGIN | TIMESTAMP | DEC 15 | |
| CREATED_ON | ZDE_DUEDATE_C60 | DATS 8 | |

User status values: `PENDING`, `ACTIVE`, `LOCKED`, `REJECTED`.

## ZPWD_RESET_C60 - Password-reset requests

| Field | Data element | Type | Key |
| --- | --- | --- | --- |
| MANDT | MANDT | CLNT 3 | Yes |
| USER_ID | ZDE_USER_ID_C60 | CHAR 12 | Yes |
| REQ_ID | - | NUMC 6 | Yes |
| OTP_HASH | ZDE_HASH_C60 | CHAR 64 | |
| EXPIRES_AT | TIMESTAMP | DEC 15 | |
| USED | - | CHAR 1 | |

## ZAUDIT_LOG_C60 - Audit trail

| Field | Data element | Type | Key |
| --- | --- | --- | --- |
| MANDT | MANDT | CLNT 3 | Yes |
| LOG_ID | - | NUMC 10 | Yes |
| USER_ID | ZDE_USER_ID_C60 | CHAR 12 | |
| ACTION | - | CHAR 20 | |
| OBJECT_KEY | - | CHAR 40 | |
| LOGGED_AT | TIMESTAMP | DEC 15 | |
| REMARK | ZDE_REMARK_C60 | CHAR 60 | |

Actions: `APPROVE`, `REJECT`, `UNLOCK` (users), `VERIFY`, `REJECT` (payments), `PRINT`, `PDF`.

## Number ranges (SNRO)

| Object | Length | Interval 01 | Used for |
| --- | --- | --- | --- |
| ZNR_PAYIDC | NUMC 10 | 0000000001 - 9999999999, no rolling | Payment IDs, drawn at submission |
| ZNR_RCPT_C | NUMC 6 | 000001 - 999999, no rolling | Receipt numbers `FR/yyyy/nnnnnn`, drawn at verification |
