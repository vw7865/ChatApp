//
//  CountryDialCode.swift
//  ChatAppTracker
//

import Foundation
import SwiftUI

struct CountryDialCode: Identifiable, Hashable, Sendable {
    let isoCode: String
    let name: String
    /// Digits only, no leading + (e.g. "61", "1").
    let dialCode: String

    var id: String { isoCode }

    var displayDialCode: String { "+\(dialCode)" }

    var flagEmoji: String {
        let upper = isoCode.uppercased()
        guard upper.count == 2 else { return "🏳️" }
        let scalars = upper.unicodeScalars.compactMap { scalar -> UnicodeScalar? in
            guard (65...90).contains(scalar.value) else { return nil }
            return UnicodeScalar(127397 + scalar.value)!
        }
        return String(String.UnicodeScalarView(scalars))
    }
}

enum CountryDialCodes {
    /// Sorted by localized country name.
    static let all: [CountryDialCode] = raw.map { CountryDialCode(isoCode: $0.0, name: $0.1, dialCode: $0.2) }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

    /// Regions that share NANP country calling code +1.
    private static let nanpRegions: Set<String> = ["US", "CA", "DO", "JM", "PR", "TT"]

    /// Best default from the device region (Settings), then United States.
    static var localeDefaultCountry: CountryDialCode {
        let id = (Locale.current.region?.identifier ?? "US").uppercased()
        if let match = all.first(where: { $0.isoCode == id }) {
            return match
        }
        return all.first { $0.isoCode == "US" } ?? all[0]
    }

    static var defaultCountry: CountryDialCode { localeDefaultCountry }

    /// Longest dial-code first so e.g. +353 matches before +3; tie-break by numeric dial code so order is stable.
    private static var byDialCodeLongestFirst: [CountryDialCode] {
        all.sorted {
            if $0.dialCode.count != $1.dialCode.count {
                return $0.dialCode.count > $1.dialCode.count
            }
            if $0.dialCode != $1.dialCode {
                return Int($0.dialCode)! > Int($1.dialCode)!
            }
            return $0.isoCode < $1.isoCode
        }
    }

    // MARK: NANP (+1)

    /// Canadian NPAs (area codes). Used to route +1 numbers to Canada instead of defaulting to the device locale (often US).
    private static let nanpCanadianAreaCodes: Set<String> = [
        "204", "226", "236", "249", "250", "263", "289", "306", "343", "354", "365", "367", "368", "382",
        "403", "416", "418", "428", "431", "437", "438", "450", "468", "474", "506", "514", "519", "548",
        "579", "581", "584", "587", "613", "639", "647", "672", "683", "705", "709", "742", "753", "778",
        "780", "782", "807", "819", "825", "867", "873", "902", "905", "942", "986",
    ]

    private static let nanpDominicanAreaCodes: Set<String> = ["809", "829", "849"]
    private static let nanpJamaicaAreaCodes: Set<String> = ["876", "658"]
    private static let nanpPuertoRicoAreaCodes: Set<String> = ["787", "939"]
    private static let nanpTrinidadAreaCodes: Set<String> = ["868"]

    /// +1: pick Canada/US/Caribbean from the 10-digit national number (NPA), then fall back to device locale.
    static func nanpCountryForNationalTenDigits(_ tenDigits: String) -> CountryDialCode {
        let digits = tenDigits.filter(\.isNumber)
        guard digits.count >= 3 else { return nanpCountryForLocale() }
        let npa = String(digits.prefix(3))
        if nanpCanadianAreaCodes.contains(npa), let c = all.first(where: { $0.isoCode == "CA" }) { return c }
        if nanpDominicanAreaCodes.contains(npa), let c = all.first(where: { $0.isoCode == "DO" }) { return c }
        if nanpJamaicaAreaCodes.contains(npa), let c = all.first(where: { $0.isoCode == "JM" }) { return c }
        if nanpPuertoRicoAreaCodes.contains(npa), let c = all.first(where: { $0.isoCode == "PR" }) { return c }
        if nanpTrinidadAreaCodes.contains(npa), let c = all.first(where: { $0.isoCode == "TT" }) { return c }
        if let c = all.first(where: { $0.isoCode == "US" }) { return c }
        return nanpCountryForLocale()
    }

    /// `true` if `digits` looks like a 10-digit NANP subscriber number (NXX-NXX-XXXX), not an international prefix.
    static func looksLikeTenDigitNanpNationalNumber(_ digits: String) -> Bool {
        let d = digits.filter(\.isNumber)
        guard d.count == 10 else { return false }
        guard let n0 = d.first?.wholeNumberValue, (2...9).contains(n0) else { return false }
        let idx3 = d.index(d.startIndex, offsetBy: 3)
        guard let x0 = d[idx3].wholeNumberValue, (2...9).contains(x0) else { return false }
        return true
    }

    /// +1: pick Canada/US/etc. from locale when possible.
    static func nanpCountryForLocale() -> CountryDialCode {
        let id = (Locale.current.region?.identifier ?? "US").uppercased()
        if nanpRegions.contains(id), let c = all.first(where: { $0.isoCode == id }) {
            return c
        }
        return all.first { $0.isoCode == "US" } ?? all[0]
    }

    /// +7: Russia and Kazakhstan share ITU code 7; prefer device region when it matches.
    private static func countryForSharedDialSeven() -> CountryDialCode {
        let id = (Locale.current.region?.identifier ?? "").uppercased()
        if id == "KZ", let c = all.first(where: { $0.isoCode == "KZ" }) { return c }
        if id == "RU", let c = all.first(where: { $0.isoCode == "RU" }) { return c }
        return all.first { $0.isoCode == "RU" } ?? all.first { $0.isoCode == "KZ" } ?? localeDefaultCountry
    }

    /// Strips optional `00` international prefix, then if digits begin with a known country calling code, returns that country and the remaining national number (digits only).
    /// Requires enough trailing digits to avoid treating a lone `1` or short stubs as a country code.
    static func parseLeadingInternationalDigits(_ digitsOnly: String) -> (country: CountryDialCode, nationalDigits: String)? {
        var d = digitsOnly.filter(\.isNumber)
        guard !d.isEmpty else { return nil }
        if d.hasPrefix("00") {
            d = String(d.dropFirst(2))
            guard !d.isEmpty else { return nil }
        }

        for country in byDialCodeLongestFirst {
            let code = country.dialCode
            guard d.hasPrefix(code) else { continue }
            let national = String(d.dropFirst(code.count))
            guard !national.isEmpty else { continue }

            if code == "1" {
                guard national.count >= 10 else { continue }
                let nanpNational = String(national.prefix(10))
                return (nanpCountryForNationalTenDigits(nanpNational), nanpNational)
            }
            if code == "7" {
                guard national.count >= 4 else { continue }
                return (countryForSharedDialSeven(), national)
            }
            guard national.count >= 4 else { continue }
            return (country, national)
        }
        return nil
    }

    /// (ISO 3166-1 alpha-2, English name, dial code digits)
    private static let raw: [(String, String, String)] = [
        ("AF", "Afghanistan", "93"),
        ("AL", "Albania", "355"),
        ("DZ", "Algeria", "213"),
        ("AD", "Andorra", "376"),
        ("AO", "Angola", "244"),
        ("AR", "Argentina", "54"),
        ("AM", "Armenia", "374"),
        ("AU", "Australia", "61"),
        ("AT", "Austria", "43"),
        ("AZ", "Azerbaijan", "994"),
        ("BH", "Bahrain", "973"),
        ("BD", "Bangladesh", "880"),
        ("BY", "Belarus", "375"),
        ("BE", "Belgium", "32"),
        ("BZ", "Belize", "501"),
        ("BJ", "Benin", "229"),
        ("BT", "Bhutan", "975"),
        ("BO", "Bolivia", "591"),
        ("BA", "Bosnia and Herzegovina", "387"),
        ("BW", "Botswana", "267"),
        ("BR", "Brazil", "55"),
        ("BN", "Brunei", "673"),
        ("BG", "Bulgaria", "359"),
        ("BF", "Burkina Faso", "226"),
        ("BI", "Burundi", "257"),
        ("KH", "Cambodia", "855"),
        ("CM", "Cameroon", "237"),
        ("CA", "Canada", "1"),
        ("CV", "Cape Verde", "238"),
        ("CF", "Central African Republic", "236"),
        ("TD", "Chad", "235"),
        ("CL", "Chile", "56"),
        ("CN", "China", "86"),
        ("CO", "Colombia", "57"),
        ("KM", "Comoros", "269"),
        ("CG", "Congo", "242"),
        ("CD", "Congo (DRC)", "243"),
        ("CR", "Costa Rica", "506"),
        ("HR", "Croatia", "385"),
        ("CU", "Cuba", "53"),
        ("CY", "Cyprus", "357"),
        ("CZ", "Czechia", "420"),
        ("DK", "Denmark", "45"),
        ("DJ", "Djibouti", "253"),
        ("DO", "Dominican Republic", "1"),
        ("EC", "Ecuador", "593"),
        ("EG", "Egypt", "20"),
        ("SV", "El Salvador", "503"),
        ("GQ", "Equatorial Guinea", "240"),
        ("ER", "Eritrea", "291"),
        ("EE", "Estonia", "372"),
        ("SZ", "Eswatini", "268"),
        ("ET", "Ethiopia", "251"),
        ("FJ", "Fiji", "679"),
        ("FI", "Finland", "358"),
        ("FR", "France", "33"),
        ("GA", "Gabon", "241"),
        ("GM", "Gambia", "220"),
        ("GE", "Georgia", "995"),
        ("DE", "Germany", "49"),
        ("GH", "Ghana", "233"),
        ("GR", "Greece", "30"),
        ("GT", "Guatemala", "502"),
        ("GN", "Guinea", "224"),
        ("GW", "Guinea-Bissau", "245"),
        ("GY", "Guyana", "592"),
        ("HT", "Haiti", "509"),
        ("HN", "Honduras", "504"),
        ("HK", "Hong Kong", "852"),
        ("HU", "Hungary", "36"),
        ("IS", "Iceland", "354"),
        ("IN", "India", "91"),
        ("ID", "Indonesia", "62"),
        ("IR", "Iran", "98"),
        ("IQ", "Iraq", "964"),
        ("IE", "Ireland", "353"),
        ("IL", "Israel", "972"),
        ("IT", "Italy", "39"),
        ("CI", "Ivory Coast", "225"),
        ("JM", "Jamaica", "1"),
        ("JP", "Japan", "81"),
        ("JO", "Jordan", "962"),
        ("KZ", "Kazakhstan", "7"),
        ("KE", "Kenya", "254"),
        ("KR", "South Korea", "82"),
        ("KW", "Kuwait", "965"),
        ("KG", "Kyrgyzstan", "996"),
        ("LA", "Laos", "856"),
        ("LV", "Latvia", "371"),
        ("LB", "Lebanon", "961"),
        ("LS", "Lesotho", "266"),
        ("LR", "Liberia", "231"),
        ("LY", "Libya", "218"),
        ("LI", "Liechtenstein", "423"),
        ("LT", "Lithuania", "370"),
        ("LU", "Luxembourg", "352"),
        ("MO", "Macao", "853"),
        ("MG", "Madagascar", "261"),
        ("MW", "Malawi", "265"),
        ("MY", "Malaysia", "60"),
        ("MV", "Maldives", "960"),
        ("ML", "Mali", "223"),
        ("MT", "Malta", "356"),
        ("MR", "Mauritania", "222"),
        ("MU", "Mauritius", "230"),
        ("MX", "Mexico", "52"),
        ("MD", "Moldova", "373"),
        ("MC", "Monaco", "377"),
        ("MN", "Mongolia", "976"),
        ("ME", "Montenegro", "382"),
        ("MA", "Morocco", "212"),
        ("MZ", "Mozambique", "258"),
        ("MM", "Myanmar", "95"),
        ("NA", "Namibia", "264"),
        ("NP", "Nepal", "977"),
        ("NL", "Netherlands", "31"),
        ("NZ", "New Zealand", "64"),
        ("NI", "Nicaragua", "505"),
        ("NE", "Niger", "227"),
        ("NG", "Nigeria", "234"),
        ("MK", "North Macedonia", "389"),
        ("NO", "Norway", "47"),
        ("OM", "Oman", "968"),
        ("PK", "Pakistan", "92"),
        ("PS", "Palestine", "970"),
        ("PA", "Panama", "507"),
        ("PG", "Papua New Guinea", "675"),
        ("PY", "Paraguay", "595"),
        ("PE", "Peru", "51"),
        ("PH", "Philippines", "63"),
        ("PL", "Poland", "48"),
        ("PT", "Portugal", "351"),
        ("PR", "Puerto Rico", "1"),
        ("QA", "Qatar", "974"),
        ("RO", "Romania", "40"),
        ("RU", "Russia", "7"),
        ("RW", "Rwanda", "250"),
        ("SA", "Saudi Arabia", "966"),
        ("SN", "Senegal", "221"),
        ("RS", "Serbia", "381"),
        ("SC", "Seychelles", "248"),
        ("SL", "Sierra Leone", "232"),
        ("SG", "Singapore", "65"),
        ("SK", "Slovakia", "421"),
        ("SI", "Slovenia", "386"),
        ("SO", "Somalia", "252"),
        ("ZA", "South Africa", "27"),
        ("SS", "South Sudan", "211"),
        ("ES", "Spain", "34"),
        ("LK", "Sri Lanka", "94"),
        ("SD", "Sudan", "249"),
        ("SR", "Suriname", "597"),
        ("SE", "Sweden", "46"),
        ("CH", "Switzerland", "41"),
        ("SY", "Syria", "963"),
        ("TW", "Taiwan", "886"),
        ("TJ", "Tajikistan", "992"),
        ("TZ", "Tanzania", "255"),
        ("TH", "Thailand", "66"),
        ("TL", "Timor-Leste", "670"),
        ("TG", "Togo", "228"),
        ("TT", "Trinidad and Tobago", "1"),
        ("TN", "Tunisia", "216"),
        ("TR", "Türkiye", "90"),
        ("TM", "Turkmenistan", "993"),
        ("UG", "Uganda", "256"),
        ("UA", "Ukraine", "380"),
        ("AE", "United Arab Emirates", "971"),
        ("GB", "United Kingdom", "44"),
        ("US", "United States", "1"),
        ("UY", "Uruguay", "598"),
        ("UZ", "Uzbekistan", "998"),
        ("VE", "Venezuela", "58"),
        ("VN", "Vietnam", "84"),
        ("YE", "Yemen", "967"),
        ("ZM", "Zambia", "260"),
        ("ZW", "Zimbabwe", "263"),
    ]
}

// MARK: - Picker

struct CountryCodePickerSheet: View {
    @Binding var selected: CountryDialCode
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [CountryDialCode] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return CountryDialCodes.all }
        return CountryDialCodes.all.filter {
            $0.name.localizedCaseInsensitiveContains(q)
                || $0.displayDialCode.contains(q.trimmingCharacters(in: CharacterSet(charactersIn: "+")))
                || $0.isoCode.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { country in
                Button {
                    selected = country
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Text(country.flagEmoji)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(country.name)
                                .foregroundStyle(.white)
                            Text(country.displayDialCode)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.mutedText)
                        }
                        Spacer(minLength: 8)
                        if country.isoCode == selected.isoCode {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.lime)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(AppTheme.followedPanel)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Country code")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search country or code")
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.lime)
                }
            }
        }
        .presentationBackground(AppTheme.background)
    }
}
