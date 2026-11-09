# Payments (UPI intent, no gateway)
Flow: app → `create_order(plan)` (server snapshots price + UPI ID, reference `OB<YYMMDD><8 hex>`) → UPI chooser → app saves the raw result locally →
`report_result` → server decides. Changing a price never touches existing orders.

**Activation modes** (Admin → Settings → Payments)
- **Manual (default, recommended):** a reported success becomes *In review*. You compare it with your bank app and press **Mark paid** (12-digit UTR). Each UTR can be used once.
- **Instant:** reported success activates immediately (max 3 auto-activations per user per 24 h). A UPI-intent result is *client-reported*, so a technical user who knows their own order reference can fake a success string. Use Instant only with the daily **Verify against bank** routine.

Other paths: `upi-webhook` / `provider-payment` edge functions (HMAC-signed) confirm orders from a bank feed; stale pending orders auto-cancel after 24 h;
payment rows are kept 8 years, anonymised if the account is deleted.
UPI: `2728412a@bandhan`, payee “As Enterprice”.
