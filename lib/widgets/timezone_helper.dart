// lib/utils/timezone_helper.dart

class TimeZoneHelper {

  /// Converts SERVER TIME (IST: UTC+5:30) to TARGET COUNTRY TIME.
  static DateTime convertIstToCountryTime(DateTime istTime, String countryName) {
    // 1. Server is Fixed at IST (UTC + 5.5)
    const double serverOffset = 5.5;

    // 2. Get Target Offset (Defaults to 0.0 if not found)
    double targetOffset = _getOffset(countryName);

    // 3. Calculate Difference (Target - IST)
    // Example: USA (-5.0) - IST (5.5) = -10.5 Hours difference
    double diffInHours = targetOffset - serverOffset;

    // 4. Apply difference
    int hours = diffInHours.truncate();
    int minutes = ((diffInHours - hours) * 60).round();

    return istTime.add(Duration(hours: hours, minutes: minutes));
  }

  static double _getOffset(String country) {
    return _countryOffsets[country] ?? 0.0;
  }

  // COMPLETE MAP based on your provided country_list.dart
  static final Map<String, double> _countryOffsets = {
    'Afghanistan': 4.5, 'Albania': 1.0, 'Algeria': 1.0, 'Andorra': 1.0, 'Angola': 1.0,
    'Antigua and Barbuda': -4.0, 'Argentina': -3.0, 'Armenia': 4.0, 'Australia': 10.0, // Canberra
    'Austria': 1.0, 'Azerbaijan': 4.0, 'Bahamas': -5.0, 'Bahrain': 3.0, 'Bangladesh': 6.0,
    'Barbados': -4.0, 'Belarus': 3.0, 'Belgium': 1.0, 'Belize': -6.0, 'Benin': 1.0,
    'Bhutan': 6.0, 'Bolivia': -4.0, 'Bosnia and Herzegovina': 1.0, 'Botswana': 2.0,
    'Brazil': -3.0, // Brasilia
    'Brunei': 8.0, 'Bulgaria': 2.0, 'Burkina Faso': 0.0, 'Burundi': 2.0, 'Cabo Verde': -1.0,
    'Cambodia': 7.0, 'Cameroon': 1.0, 'Canada': -5.0, // Ottawa
    'Central African Republic': 1.0, 'Chad': 1.0, 'Chile': -4.0, 'China': 8.0,
    'Colombia': -5.0, 'Comoros': 3.0, 'Congo (Congo-Brazzaville)': 1.0, 'Costa Rica': -6.0,
    'Croatia': 1.0, 'Cuba': -5.0, 'Cyprus': 2.0, 'Czechia (Czech Republic)': 1.0,
    'Democratic Republic of the Congo': 1.0, 'Denmark': 1.0, 'Djibouti': 3.0,
    'Dominica': -4.0, 'Dominican Republic': -4.0, 'Ecuador': -5.0, 'Egypt': 2.0,
    'El Salvador': -6.0, 'Equatorial Guinea': 1.0, 'Eritrea': 3.0, 'Estonia': 2.0,
    'Eswatini (fmr. "Swaziland")': 2.0, 'Ethiopia': 3.0, 'Fiji': 12.0, 'Finland': 2.0,
    'France': 1.0, 'Gabon': 1.0, 'Gambia': 0.0, 'Georgia': 4.0, 'Germany': 1.0,
    'Ghana': 0.0, 'Greece': 2.0, 'Grenada': -4.0, 'Guatemala': -6.0, 'Guinea': 0.0,
    'Guinea-Bissau': 0.0, 'Guyana': -4.0, 'Haiti': -5.0, 'Holy See': 1.0, 'Honduras': -6.0,
    'Hungary': 1.0, 'Iceland': 0.0, 'India': 5.5, 'Indonesia': 7.0, 'Iran': 3.5,
    'Iraq': 3.0, 'Ireland': 0.0, 'Israel': 2.0, 'Italy': 1.0, 'Jamaica': -5.0,
    'Japan': 9.0, 'Jordan': 3.0, 'Kazakhstan': 6.0, 'Kenya': 3.0, 'Kiribati': 14.0,
    'Kuwait': 3.0, 'Kyrgyzstan': 6.0, 'Laos': 7.0, 'Latvia': 2.0, 'Lebanon': 2.0,
    'Lesotho': 2.0, 'Liberia': 0.0, 'Libya': 2.0, 'Liechtenstein': 1.0, 'Lithuania': 2.0,
    'Luxembourg': 1.0, 'Madagascar': 3.0, 'Malawi': 2.0, 'Malaysia': 8.0, 'Maldives': 5.0,
    'Mali': 0.0, 'Malta': 1.0, 'Marshall Islands': 12.0, 'Mauritania': 0.0, 'Mauritius': 4.0,
    'Mexico': -6.0, 'Micronesia': 11.0, 'Moldova': 2.0, 'Monaco': 1.0, 'Mongolia': 8.0,
    'Montenegro': 1.0, 'Morocco': 1.0, 'Mozambique': 2.0, 'Myanmar (formerly Burma)': 6.5,
    'Namibia': 2.0, 'Nauru': 12.0, 'Nepal': 5.75, 'Netherlands': 1.0, 'New Zealand': 12.0,
    'Nicaragua': -6.0, 'Niger': 1.0, 'Nigeria': 1.0, 'North Korea': 9.0, 'North Macedonia': 1.0,
    'Norway': 1.0, 'Oman': 4.0, 'Pakistan': 5.0, 'Palau': 9.0, 'Palestine State': 2.0,
    'Panama': -5.0, 'Papua New Guinea': 10.0, 'Paraguay': -4.0, 'Peru': -5.0, 'Philippines': 8.0,
    'Poland': 1.0, 'Portugal': 0.0, 'Qatar': 3.0, 'Romania': 2.0, 'Russia': 3.0, // Moscow
    'Rwanda': 2.0, 'Saint Kitts and Nevis': -4.0, 'Saint Lucia': -4.0,
    'Saint Vincent and the Grenadines': -4.0, 'Samoa': 13.0, 'San Marino': 1.0,
    'Sao Tome and Principe': 0.0, 'Saudi Arabia': 3.0, 'Senegal': 0.0, 'Serbia': 1.0,
    'Seychelles': 4.0, 'Sierra Leone': 0.0, 'Singapore': 8.0, 'Slovakia': 1.0, 'Slovenia': 1.0,
    'Solomon Islands': 11.0, 'Somalia': 3.0, 'South Africa': 2.0, 'South Korea': 9.0,
    'South Sudan': 2.0, 'Spain': 1.0, 'Sri Lanka': 5.5, 'Sudan': 2.0, 'Suriname': -3.0,
    'Sweden': 1.0, 'Switzerland': 1.0, 'Syria': 3.0, 'Tajikistan': 5.0, 'Tanzania': 3.0,
    'Thailand': 7.0, 'Timor-Leste': 9.0, 'Togo': 0.0, 'Tonga': 13.0, 'Trinidad and Tobago': -4.0,
    'Tunisia': 1.0, 'Turkey': 3.0, 'Turkmenistan': 5.0, 'Tuvalu': 12.0, 'Uganda': 3.0,
    'Ukraine': 2.0, 'United Arab Emirates': 4.0, 'United Kingdom': 0.0,
    'United States of America': -5.0, // EST
    'Uruguay': -3.0, 'Uzbekistan': 5.0, 'Vanuatu': 11.0, 'Venezuela': -4.0, 'Vietnam': 7.0,
    'Yemen': 3.0, 'Zambia': 2.0, 'Zimbabwe': 2.0
  };
}