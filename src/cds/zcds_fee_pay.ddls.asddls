@AbapCatalog.sqlViewName: 'ZCDS_FEE_C60'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Student Fee Payment'
@Metadata.ignorePropagatedAnnotations: true
@OData.publish: true

// Step 17 - one row per PAYMENT, with the student, the fee demand it
// belongs to and the receipt. Used by the ALV reports of Step 18
// and published as an OData service.
define view ZCDS_FEE_PAY
  as select from zpayment_c60 as p
    inner join   zstudent_cs60 as s
      on p.reg_no = s.reg_no
    left outer join zfee_details_c60 as f
      on  f.reg_no        = p.reg_no
      and f.academic_year = substring(p.academic_year, 1, 1)
      and f.fee_type      = p.fee_type
    left outer join zreceipt_c60 as r
      on r.receipt_no = p.receipt_no
{
  key p.payment_id,
  key p.reg_no,

      // student
      s.name,
      s.branch,
      s.course,
      s.studyyear,

      // payment (old names kept)
      p.transaction_id,

      @Semantics.amount.currencyCode: 'Currency'
      p.amount        as Amount,

      @Semantics.currencyCode: true
      p.currency      as Currency,

      p.payment_mode,
      p.payment_date,
      p.status,

      // payment (new)
      p.fee_type,
      p.academic_year,
      p.bank_name,
      p.entered_by,
      p.verified_by,
      p.verified_on,
      p.remark,
      p.receipt_no,

      // receipt
      r.issued_on,
      r.print_count,
      r.cancelled,

      // fee demand of this payment
      @Semantics.currencyCode: true
      f.currency      as FeeCurrency,

      @Semantics.amount.currencyCode: 'FeeCurrency'
      f.total_fee     as TotalFee,

      @Semantics.amount.currencyCode: 'FeeCurrency'
      f.concession    as Concession,

      @Semantics.amount.currencyCode: 'FeeCurrency'
      f.late_fee      as LateFee,

      @Semantics.amount.currencyCode: 'FeeCurrency'
      f.paid_amount   as PaidAmount,

      @Semantics.amount.currencyCode: 'FeeCurrency'
      f.balance       as Balance,

      f.due_date
}
