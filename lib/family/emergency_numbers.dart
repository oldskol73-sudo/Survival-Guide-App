// Local emergency numbers by country, shown on the Family tab. Built in, so it works offline.
// Always double-check the number for the place you are actually in; this is a convenience, not a guarantee.

class EmergencyInfo {
  const EmergencyInfo(this.name, this.numbers);
  final String name;

  /// Label -> number, in the order shown.
  final List<(String, String)> numbers;
}

const _all112 = [('Emergency', '112')];

const emergencyByCountry = <String, EmergencyInfo>{
  'US': EmergencyInfo('United States', [('Emergency', '911')]),
  'CA': EmergencyInfo('Canada', [('Emergency', '911')]),
  'MX': EmergencyInfo('Mexico', [('Emergency', '911')]),
  'GB': EmergencyInfo('United Kingdom', [('Emergency', '999'), ('Also', '112')]),
  'IE': EmergencyInfo('Ireland', [('Emergency', '112'), ('Also', '999')]),
  'AU': EmergencyInfo('Australia', [('Emergency', '000'), ('Mobile', '112')]),
  'NZ': EmergencyInfo('New Zealand', [('Emergency', '111')]),
  'DE': EmergencyInfo('Germany', [('Emergency', '112'), ('Police', '110')]),
  'FR': EmergencyInfo('France', [('Emergency', '112'), ('Medical', '15'), ('Police', '17'), ('Fire', '18')]),
  'ES': EmergencyInfo('Spain', _all112),
  'PT': EmergencyInfo('Portugal', _all112),
  'NL': EmergencyInfo('Netherlands', _all112),
  'BE': EmergencyInfo('Belgium', _all112),
  'IT': EmergencyInfo('Italy', [('Emergency', '112'), ('Police', '113'), ('Medical', '118'), ('Fire', '115')]),
  'TR': EmergencyInfo('Türkiye', [('Emergency', '112'), ('Police', '155'), ('Fire', '110'), ('Jandarma', '156')]),
  'IN': EmergencyInfo('India', [('Emergency', '112'), ('Police', '100'), ('Fire', '101'), ('Ambulance', '102')]),
  'JP': EmergencyInfo('Japan', [('Police', '110'), ('Fire/Ambulance', '119')]),
};

/// Fallback when the country is not in the table: 112 works on GSM networks in most of the world.
const fallbackEmergency = EmergencyInfo('Other region', _all112);

EmergencyInfo emergencyFor(String? countryCode) => emergencyByCountry[countryCode?.toUpperCase()] ?? fallbackEmergency;

/// Regional-indicator flag emoji for a two-letter country code ("" if not a valid code).
String flagFor(String? code) {
  if (code == null || code.length != 2) return '';
  final c = code.toUpperCase().codeUnits;
  if (c.any((u) => u < 65 || u > 90)) return '';
  return String.fromCharCodes([for (final u in c) 0x1F1E6 + (u - 65)]);
}
