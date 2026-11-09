-- Owner request: plans activate automatically when the UPI app reports a successful payment.
update public.payment_settings set activation_mode = 'instant' where id = 1;
