import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var isForceSyncingSnapshot = false

    // MARK: - Unit system

    @AppStorage(UnitSystem.storageKey) private var unitSystemRaw: String = UnitSystem.metric.rawValue

    // MARK: - Personal profile
    // When Apple Health sync lands, replace these @AppStorage bindings with
    // HKHealthStore queries (see UserProfile.StorageKey for the matching HK identifiers).

    @AppStorage(UserProfile.StorageKey.heightCm)       private var heightCm: Double = 0
    @AppStorage(UserProfile.StorageKey.weightKg)       private var weightKg: Double = 0
    @AppStorage(UserProfile.StorageKey.targetWeightKg) private var targetWeightKg: Double = 0
    /// Stored as seconds since Unix epoch; 0 means the user has not set a birthdate.
    @AppStorage(UserProfile.StorageKey.birthDateEpoch) private var birthDateEpoch: Double = 0
    @AppStorage(UserProfile.StorageKey.sex)            private var sexRaw: String = UserProfile.BiologicalSex.male.rawValue
    @AppStorage(UserProfile.StorageKey.activityLevel)  private var activityLevelRaw: String = UserProfile.ActivityLevel.moderatelyActive.rawValue

    // MARK: - Daily goals

    @AppStorage(NutritionTargets.StorageKey.calories)     private var calories: Double = NutritionTargets.default.calories
    @AppStorage(NutritionTargets.StorageKey.carbsGrams)   private var carbs: Double = NutritionTargets.default.carbsGrams
    @AppStorage(NutritionTargets.StorageKey.proteinGrams) private var protein: Double = NutritionTargets.default.proteinGrams
    @AppStorage(NutritionTargets.StorageKey.fatGrams)     private var fat: Double = NutritionTargets.default.fatGrams

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                unitsSection
                streakSection
                mealsSection
                personalSection
                dailyGoalsSection
                widgetSection
                comingSoonSection
                aboutSection
            }
            .navigationTitle("Settings")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            // Heal macros that may have been zeroed by a previous bad state.
            .onAppear(perform: restoreInvalidMacros)
            // Cascade calorie changes into proportional macro adjustments.
            .onChange(of: calories) { oldValue, newValue in
                adjustMacros(from: oldValue, to: newValue)
                refreshCalorieWidgetFromLogbook()
            }
        }
    }

    // MARK: - Sections

    private var streakSection: some View {
        Section {
            NavigationLink {
                StreakView()
            } label: {
                Label("Daily streak", systemImage: "flame.fill")
            }
        } header: {
            Text("Engagement")
        }
    }

    private var mealsSection: some View {
        Section("Meals") {
            NavigationLink {
                MealsListView()
            } label: {
                Label("Your meals", systemImage: "fork.knife")
            }
        }
    }

    private var unitsSection: some View {
        Section("Units") {
            Picker("Measurement system", selection: unitSystemBinding) {
                ForEach(UnitSystem.allCases, id: \.self) { system in
                    Text(system.displayName).tag(system)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var personalSection: some View {
        Section {
            heightRow
            weightRow
            targetWeightRow

            DatePicker(
                "Date of Birth",
                selection: birthDateBinding,
                in: ...maxBirthDate,
                displayedComponents: .date
            )

            if let age = currentProfile.age {
                LabeledContent("Age", value: "\(age) years")
            }

            Picker("Biological Sex", selection: sexBinding) {
                ForEach(UserProfile.BiologicalSex.allCases, id: \.self) { s in
                    Text(s.displayName).tag(s)
                }
            }

            Picker("Activity Level", selection: activityLevelBinding) {
                ForEach(UserProfile.ActivityLevel.allCases, id: \.self) { level in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(level.displayName)
                        Text(level.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(level)
                }
            }
        } header: {
            Text("Personal")
        } footer: {
            Text("Used with Mifflin–St Jeor to estimate your daily burn and calorie goal. Changing these values updates Daily Goals below. Open the Forecast tab for BMR, TDEE, and a weight-loss projection.")
        }
        .onChange(of: heightCm,        recalculateGoals)
        .onChange(of: weightKg,        recalculateGoals)
        .onChange(of: birthDateEpoch,  recalculateGoals)
        .onChange(of: sexRaw,          recalculateGoals)
        .onChange(of: activityLevelRaw, recalculateGoals)
    }

    private var heightRow: some View {
        LabeledContent("Height") {
            HStack(spacing: 4) {
                if isMetric {
                    TextField("cm", value: $heightCm, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("cm").foregroundStyle(.secondary)
                } else {
                    TextField("ft", value: heightFeetBinding, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 44)
                    Text("ft").foregroundStyle(.secondary)
                    TextField("in", value: heightInchesBinding, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 44)
                    Text("in").foregroundStyle(.secondary)
                }
            }
        }
    }

    private var weightRow: some View {
        LabeledContent("Weight") {
            HStack(spacing: 4) {
                TextField(isMetric ? "kg" : "lbs", value: weightDisplayBinding, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text(isMetric ? "kg" : "lbs").foregroundStyle(.secondary)
            }
        }
    }

    private var targetWeightRow: some View {
        LabeledContent("Target weight") {
            HStack(spacing: 4) {
                TextField(isMetric ? "kg" : "lbs", value: targetWeightDisplayBinding, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text(isMetric ? "kg" : "lbs").foregroundStyle(.secondary)
            }
        }
    }

    private var dailyGoalsSection: some View {
        Section {
            goalRow(label: "Calories",      unit: "kcal", value: $calories)
            goalRow(label: "Carbohydrates", unit: "g",    value: $carbs)
            goalRow(label: "Protein",       unit: "g",    value: $protein)
            goalRow(label: "Fat",           unit: "g",    value: $fat)
        } header: {
            Text("Daily Goals")
        } footer: {
            Button("Reset to defaults") {
                calories = NutritionTargets.default.calories
                carbs    = NutritionTargets.default.carbsGrams
                protein  = NutritionTargets.default.proteinGrams
                fat      = NutritionTargets.default.fatGrams
            }
            .font(.footnote)
        }
        .onChange(of: carbs) { _, _ in refreshCalorieWidgetFromLogbook() }
        .onChange(of: protein) { _, _ in refreshCalorieWidgetFromLogbook() }
        .onChange(of: fat) { _, _ in refreshCalorieWidgetFromLogbook() }
    }

    private var widgetSection: some View {
        Section {
            Button {
                Task { await forceSyncSharedSnapshotToWidgetAndWatch() }
            } label: {
                HStack {
                    Label("Sync home screen widget", systemImage: "arrow.triangle.2.circlepath")
                    Spacer()
                    if isForceSyncingSnapshot {
                        ProgressView()
                    }
                }
            }
            .disabled(isForceSyncingSnapshot || dependencies?.logbook == nil)

            Button {
                Task { await forceSyncSharedSnapshotToWidgetAndWatch() }
            } label: {
                HStack {
                    Label("Sync Apple Watch", systemImage: "applewatch")
                    Spacer()
                    if isForceSyncingSnapshot {
                        ProgressView()
                    }
                }
            }
            .disabled(isForceSyncingSnapshot || dependencies?.logbook == nil)
        } header: {
            Text("Widget & Apple Watch")
        } footer: {
            Text("Rebuilds today’s shared snapshot from your log, reloads home screen widgets, and pings your Apple Watch. Use either control if the ring or Watch Today looks stale.")
        }
    }

    private var comingSoonSection: some View {
        Section("Coming soon") {
            Label("Apple Health sync", systemImage: "heart.fill")
                .foregroundStyle(.pink.opacity(0.6))
            Label("Custom foods & recipes", systemImage: "fork.knife.circle")
            Label("Widgets & Live Activities", systemImage: "rectangle.stack.badge.play")
            Label("Siri / App Intents", systemImage: "mic.fill")
            Label("iCloud sync", systemImage: "cloud.fill")
        }
        .foregroundStyle(.secondary)
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "0.1.0 (POC)")
            LabeledContent("Data source", value: "Open Food Facts")
        }
    }

    // MARK: - Logic

    private var currentProfile: UserProfile {
        UserProfile(
            heightCm:     heightCm,
            weightKg:     weightKg,
            birthDate:    birthDateEpoch > 0 ? Date(timeIntervalSince1970: birthDateEpoch) : nil,
            sex:          UserProfile.BiologicalSex(rawValue: sexRaw) ?? .male,
            activityLevel: UserProfile.ActivityLevel(rawValue: activityLevelRaw) ?? .moderatelyActive
        )
    }

    /// Recalculates the calorie goal from TDEE whenever a profile field changes.
    /// No-ops silently when the profile is incomplete.
    private func recalculateGoals() {
        guard let tdee = currentProfile.tdee else { return }
        calories = tdee.rounded()
    }

    /// Scales macros proportionally when the calorie target changes.
    /// If a macro is zero or negative (bad stored state), falls back to the default ratio.
    private func adjustMacros(from oldCalories: Double, to newCalories: Double) {
        guard oldCalories > 0, newCalories > 0 else { return }
        let d = NutritionTargets.default
        let scale = newCalories / oldCalories
        carbs   = carbs   > 0 ? (carbs   * scale).rounded() : (d.carbsGrams   * newCalories / d.calories).rounded()
        protein = protein > 0 ? (protein * scale).rounded() : (d.proteinGrams * newCalories / d.calories).rounded()
        fat     = fat     > 0 ? (fat     * scale).rounded() : (d.fatGrams     * newCalories / d.calories).rounded()
    }

    /// Restores any macro that is ≤ 0 to the proportional default for the current calorie goal.
    /// Guards against a corrupted UserDefaults state where macros were stored as zero.
    private func restoreInvalidMacros() {
        guard calories > 0 else { return }
        let d = NutritionTargets.default
        let scale = calories / d.calories
        if carbs   <= 0 { carbs   = (d.carbsGrams   * scale).rounded() }
        if protein <= 0 { protein = (d.proteinGrams * scale).rounded() }
        if fat     <= 0 { fat     = (d.fatGrams     * scale).rounded() }
    }

    // MARK: - Bindings

    private var isMetric: Bool { UnitSystem(rawValue: unitSystemRaw) == .metric }

    /// Maximum selectable birthdate — must be at least 10 years ago.
    private var maxBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -10, to: .now) ?? .now
    }

    /// When no birthdate is stored, defaults the picker to 25 years ago so the
    /// wheel opens in a realistic position rather than today (which would show age 0).
    private var birthDateBinding: Binding<Date> {
        let defaultDate = Calendar.current.date(byAdding: .year, value: -25, to: .now) ?? .now
        return Binding(
            get: { birthDateEpoch > 0 ? Date(timeIntervalSince1970: birthDateEpoch) : defaultDate },
            set: { birthDateEpoch = $0.timeIntervalSince1970 }
        )
    }

    /// Height displayed as raw centimetres when metric.
    /// In imperial, feet and inches are decomposed from the stored centimetre value.
    private var heightFeetBinding: Binding<Int> {
        Binding(
            get: { heightCm > 0 ? Int(heightCm / 30.48) : 0 },
            set: { ft in
                let inches = heightCm > 0 ? Int((heightCm / 2.54).truncatingRemainder(dividingBy: 12)) : 0
                heightCm = Double(ft) * 30.48 + Double(inches) * 2.54
            }
        )
    }

    private var heightInchesBinding: Binding<Int> {
        Binding(
            get: { heightCm > 0 ? Int((heightCm / 2.54).truncatingRemainder(dividingBy: 12)) : 0 },
            set: { rawInches in
                let ft = heightCm > 0 ? Int(heightCm / 30.48) : 0
                let inches = min(max(0, rawInches), 11)   // clamp to valid range
                heightCm = Double(ft) * 30.48 + Double(inches) * 2.54
            }
        )
    }

    private var weightDisplayBinding: Binding<Double> {
        Binding(
            get: {
                guard weightKg > 0 else { return 0 }
                return isMetric ? weightKg : (weightKg * 2.20462 * 10).rounded() / 10
            },
            set: { weightKg = isMetric ? $0 : $0 / 2.20462 }
        )
    }

    private var targetWeightDisplayBinding: Binding<Double> {
        Binding(
            get: {
                guard targetWeightKg > 0 else { return 0 }
                return isMetric ? targetWeightKg : (targetWeightKg * 2.20462 * 10).rounded() / 10
            },
            set: { targetWeightKg = isMetric ? $0 : $0 / 2.20462 }
        )
    }

    private var unitSystemBinding: Binding<UnitSystem> {
        Binding(
            get: { UnitSystem(rawValue: unitSystemRaw) ?? .metric },
            set: { unitSystemRaw = $0.rawValue }
        )
    }

    private var sexBinding: Binding<UserProfile.BiologicalSex> {
        Binding(
            get: { UserProfile.BiologicalSex(rawValue: sexRaw) ?? .male },
            set: { sexRaw = $0.rawValue }
        )
    }

    private var activityLevelBinding: Binding<UserProfile.ActivityLevel> {
        Binding(
            get: { UserProfile.ActivityLevel(rawValue: activityLevelRaw) ?? .moderatelyActive },
            set: { activityLevelRaw = $0.rawValue }
        )
    }

    private func refreshCalorieWidgetFromLogbook() {
        guard let logbook = dependencies?.logbook else { return }
        Task { await TodaySnapshotPublisher.refresh(logbook: logbook) }
    }

    @MainActor
    private func forceSyncSharedSnapshotToWidgetAndWatch() async {
        guard let logbook = dependencies?.logbook else { return }
        isForceSyncingSnapshot = true
        defer { isForceSyncingSnapshot = false }
        await TodaySnapshotPublisher.forceSync(logbook: logbook)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func goalRow(label: String, unit: String, value: Binding<Double>) -> some View {
        LabeledContent(label) {
            HStack(spacing: 4) {
                TextField("0", value: value, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text(unit).foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    SettingsView()
}
