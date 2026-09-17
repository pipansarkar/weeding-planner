class Currency {
  final String code;
  final String symbol;
  final String label;

  const Currency({required this.code, required this.symbol, required this.label});

  static const List<Currency> all = [
    Currency(code: 'INR', symbol: '₹', label: 'Indian Rupee'),
    Currency(code: 'BDT', symbol: '৳', label: 'Bangladeshi Taka'),
    Currency(code: 'USD', symbol: '\$', label: 'US Dollar'),
    Currency(code: 'EUR', symbol: '€', label: 'Euro'),
    Currency(code: 'GBP', symbol: '£', label: 'British Pound'),
    Currency(code: 'PKR', symbol: '₨', label: 'Pakistani Rupee'),
    Currency(code: 'AED', symbol: 'د.إ', label: 'UAE Dirham'),
    Currency(code: 'SAR', symbol: '﷼', label: 'Saudi Riyal'),
    Currency(code: 'MYR', symbol: 'RM', label: 'Malaysian Ringgit'),
    Currency(code: 'SGD', symbol: 'S\$', label: 'Singapore Dollar'),
    Currency(code: 'AUD', symbol: 'A\$', label: 'Australian Dollar'),
    Currency(code: 'CAD', symbol: 'C\$', label: 'Canadian Dollar'),
    Currency(code: 'NPR', symbol: 'रु', label: 'Nepalese Rupee'),
    Currency(code: 'LKR', symbol: 'Rs', label: 'Sri Lankan Rupee'),
    Currency(code: 'JPY', symbol: '¥', label: 'Japanese Yen'),
    Currency(code: 'CNY', symbol: '¥', label: 'Chinese Yuan'),
    Currency(code: 'ZAR', symbol: 'R', label: 'South African Rand'),
    Currency(code: 'NGN', symbol: '₦', label: 'Nigerian Naira'),
    Currency(code: 'KWD', symbol: 'د.ك', label: 'Kuwaiti Dinar'),
    Currency(code: 'QAR', symbol: 'ر.ق', label: 'Qatari Riyal'),
  ];

  static Currency byCode(String code) =>
      all.firstWhere((c) => c.code == code, orElse: () => all.first);
}
