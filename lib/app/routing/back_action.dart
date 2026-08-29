/// What the Android back gesture should do at the top of ZePOS.
enum BackAction {
  /// A sale is part rung up, so leaving has to be confirmed first.
  confirmLeave,

  /// Another section is on screen; back returns to the till before it ever
  /// leaves the app, which is how Android apps with tabs behave.
  goToCashier,

  /// Nothing is at stake, so back closes the app as it normally would.
  leave,
}

/// Decides what back does, given only what the decision depends on.
///
/// Back is the most used gesture on a phone, and here it used to close ZePOS
/// outright: a cashier halfway through ringing up a customer lost the whole
/// basket. Windows has no back button, which is why that went unnoticed.
///
/// Kept apart from the widget so the rule can be read and tested on its own.
BackAction decideBackAction({
  required int cartItemCount,
  required int activeSection,
  required int cashierSection,
}) {
  // An unpaid basket outranks everything: it is the only thing here that
  // cannot be recovered by reopening the app.
  if (cartItemCount > 0) return BackAction.confirmLeave;
  if (activeSection != cashierSection) return BackAction.goToCashier;
  return BackAction.leave;
}
