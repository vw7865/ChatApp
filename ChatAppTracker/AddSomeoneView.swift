//
//  AddSomeoneView.swift
//  ChatAppTracker
//

import Contacts
import ContactsUI
import SwiftUI

struct AddSomeoneView: View {
    @EnvironmentObject private var tracking: ContactTrackingStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var selectedCountry: CountryDialCode = CountryDialCodes.localeDefaultCountry
    @State private var showCountryPicker = false
    @State private var showContactPicker = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case name, phone
    }

    private var formattedPhone: String {
        let digits = phone.filter(\.isNumber)
        guard !digits.isEmpty else { return selectedCountry.displayDialCode }
        return "\(selectedCountry.displayDialCode) \(digits)"
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                headerTitle

                VStack(alignment: .leading, spacing: 10) {
                    Text("Contact")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.mutedText)

                    darkFormCard
                }

                chooseFromContactsButton

                Button(action: saveTapped) {
                    Text("Save")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(canSave ? Color.black.opacity(0.88) : AppTheme.mutedText)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                        .background(canSave ? AppTheme.lime : AppTheme.statisticsCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(AppTheme.divider, lineWidth: canSave ? 0 : 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppTheme.background)
        .navigationTitle("Add someone")
        .navigationBarTitleDisplayMode(.inline)
        .appThemedNavigationBar()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.lime)
            }
        }
        .sheet(isPresented: $showCountryPicker) {
            CountryCodePickerSheet(selected: $selectedCountry)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showContactPicker) {
            ContactPickerPresenter { contact in
                applyPickedContact(contact)
            } onCancel: {
                showContactPicker = false
            }
            .presentationBackground(.clear)
        }
    }

    private func saveTapped() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tracking.addCustomContact(name: trimmed, phoneDisplay: formattedPhone)
        dismiss()
    }

    /// When the user types or pastes a full international number (e.g. +44…, 00 44…), move the prefix into the country picker and keep only the national digits in the field.
    /// National-only input (e.g. Calgary 403…) is left alone so we do not treat `40` as Romania or re-parse Paraguayan numbers that start with another country code (e.g. `98`).
    private func syncCountryCodeFromPhoneField(_ value: String) {
        let digits = value.filter(\.isNumber)
        let hasPlus = value.contains { $0 == "+" || $0 == "＋" }
        let treatAsInternationalInput =
            hasPlus
            || digits.hasPrefix("00")
            || digits.count >= 11

        if !treatAsInternationalInput {
            if digits.count == 10, CountryDialCodes.looksLikeTenDigitNanpNationalNumber(digits) {
                return
            }
            return
        }

        guard let parsed = CountryDialCodes.parseLeadingInternationalDigits(value) else { return }
        selectedCountry = parsed.country
        phone = parsed.nationalDigits
    }

    private func applyPickedContact(_ contact: CNContact) {
        showContactPicker = false
        let formatter = CNContactFormatter()
        formatter.style = .fullName
        let fullName = formatter.string(from: contact) ?? ""
        let org = contact.organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        name = resolvedName.isEmpty ? org : resolvedName

        guard let phoneNumber = contact.phoneNumbers.first?.value as CNPhoneNumber? else {
            phone = ""
            return
        }
        let digitsOnly = phoneNumber.stringValue.filter(\.isNumber)
        guard !digitsOnly.isEmpty else {
            phone = ""
            return
        }
        if digitsOnly.count == 10, CountryDialCodes.looksLikeTenDigitNanpNationalNumber(digitsOnly) {
            selectedCountry = CountryDialCodes.nanpCountryForNationalTenDigits(digitsOnly)
            phone = digitsOnly
            return
        }
        if let parsed = CountryDialCodes.parseLeadingInternationalDigits(digitsOnly) {
            selectedCountry = parsed.country
            phone = parsed.nationalDigits
        } else {
            phone = digitsOnly
        }
    }

    private var headerTitle: some View {
        Text("Add the Contact You Want to Follow")
            .font(.title2.weight(.bold))
            .foregroundStyle(.white.opacity(0.95))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var chooseFromContactsButton: some View {
        Button {
            focusedField = nil
            showContactPicker = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.lime)
                Text("Choose from Contacts")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mutedText)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.statisticsCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AppTheme.lime.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var darkFormCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            darkLabeledField(title: "Name") {
                TextField("Full name", text: $name)
                    .focused($focusedField, equals: .name)
                    .textContentType(.name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .phone }
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            darkLabeledField(title: "Phone") {
                HStack(spacing: 0) {
                    Button {
                        focusedField = nil
                        showCountryPicker = true
                    } label: {
                        HStack(spacing: 6) {
                            Text(selectedCountry.flagEmoji)
                                .font(.title3)
                            Text(selectedCountry.displayDialCode)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.mutedText)
                        }
                        .frame(minHeight: 44)
                        .padding(.horizontal, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Rectangle()
                        .fill(AppTheme.divider)
                        .frame(width: 1)
                        .padding(.vertical, 10)

                    TextField("Mobile number", text: $phone)
                        .focused($focusedField, equals: .phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onChange(of: phone) { _, newValue in
                            syncCountryCodeFromPhoneField(newValue)
                        }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.statisticsCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(AppTheme.lime.opacity(0.22), lineWidth: 1)
        )
    }

    private func darkLabeledField(title: String, @ViewBuilder field: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.mutedText)
            field()
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.nestedCardFill)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

// MARK: - System contact picker

private struct ContactPickerPresenter: UIViewControllerRepresentable {
    var onPick: (CNContact) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (CNContact) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (CNContact) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onPick(contact)
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onCancel()
        }
    }

    func makeUIViewController(context: Context) -> ContactPickerHostViewController {
        let host = ContactPickerHostViewController()
        host.presentPicker = { [weak host] in
            guard let host else { return }
            let picker = CNContactPickerViewController()
            picker.delegate = context.coordinator
            host.present(picker, animated: true)
        }
        return host
    }

    func updateUIViewController(_ uiViewController: ContactPickerHostViewController, context: Context) {}
}

private final class ContactPickerHostViewController: UIViewController {
    var presentPicker: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let presentPicker {
            self.presentPicker = nil
            presentPicker()
        }
    }
}

#Preview {
    NavigationStack {
        AddSomeoneView()
            .environmentObject(ContactTrackingStore())
    }
}
