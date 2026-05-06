import Charts
import SwiftUI

struct WeightLossForecastView: View {

    @AppStorage(UnitSystem.storageKey) private var unitSystemRaw: String = UnitSystem.metric.rawValue
    @AppStorage(UserProfile.StorageKey.heightCm) private var heightCm: Double = 0
    @AppStorage(UserProfile.StorageKey.weightKg) private var weightKg: Double = 0
    @AppStorage(UserProfile.StorageKey.targetWeightKg) private var targetWeightKg: Double = 0
    @AppStorage(UserProfile.StorageKey.birthDateEpoch) private var birthDateEpoch: Double = 0
    @AppStorage(UserProfile.StorageKey.sex) private var sexRaw: String = UserProfile.BiologicalSex.male.rawValue
    @AppStorage(UserProfile.StorageKey.activityLevel) private var activityLevelRaw: String = UserProfile.ActivityLevel.moderatelyActive.rawValue
    @AppStorage(NutritionTargets.StorageKey.calories) private var calorieTarget: Double = NutritionTargets.default.calories

    @State private var visibleActivities: Set<UserProfile.ActivityLevel> = Set(UserProfile.ActivityLevel.allCases)
    @State private var seriesList: [WeightLossForecastSimulator.Series] = []

    private var unitSystem: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }
    private var isMetric: Bool { unitSystem == .metric }

    private var profile: UserProfile {
        UserProfile(
            heightCm: heightCm,
            weightKg: weightKg,
            birthDate: birthDateEpoch > 0 ? Date(timeIntervalSince1970: birthDateEpoch) : nil,
            sex: UserProfile.BiologicalSex(rawValue: sexRaw) ?? .male,
            activityLevel: UserProfile.ActivityLevel(rawValue: activityLevelRaw) ?? .moderatelyActive
        )
    }

    private var userActivityLevel: UserProfile.ActivityLevel {
        UserProfile.ActivityLevel(rawValue: activityLevelRaw) ?? .moderatelyActive
    }

    /// Stable key so we re-simulate only when forecast inputs change (simulation can be thousands of steps).
    private var simulationInputsKey: String {
        [
            String(heightCm),
            String(weightKg),
            String(targetWeightKg),
            String(birthDateEpoch),
            sexRaw,
            String(calorieTarget)
        ].joined(separator: "|")
    }

    private var chartPoints: [ForecastChartPoint] {
        seriesList.flatMap { series in
            guard visibleActivities.contains(series.activityLevel) else { return [ForecastChartPoint]() }
            return series.points.map { day, kg in
                ForecastChartPoint(day: day, weightKg: kg, activityLevel: series.activityLevel)
            }
        }
    }

    var body: some View {
        List {
            if !canRunForecast {
                Section {
                    ContentUnavailableView(
                        "Incomplete profile",
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text(missingDataMessage)
                    )
                }
            } else if targetWeightKg <= 0 {
                Section {
                    ContentUnavailableView(
                        "Set a target weight",
                        systemImage: "target",
                        description: Text("Add a goal weight in Settings → Personal. It should be below your current weight.")
                    )
                }
            } else if weightKg <= targetWeightKg {
                Section {
                    ContentUnavailableView(
                        "Adjust your goal",
                        systemImage: "arrow.down.circle",
                        description: Text("Your target weight needs to be less than your current weight for a loss forecast.")
                    )
                }
            } else {
                summarySection
                chartSection
                disclaimerSection
            }

            activityLegendSection
        }
        .navigationTitle("Weight loss forecast")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: simulationInputsKey) {
            guard canRunForecast, targetWeightKg > 0, weightKg > targetWeightKg else {
                seriesList = []
                return
            }
            seriesList = WeightLossForecastSimulator.allActivitySeries(
                profile: profile,
                targetWeightKg: targetWeightKg,
                dailyCalorieIntake: calorieTarget
            )
        }
    }

    private var canRunForecast: Bool {
        heightCm > 0 && weightKg > 0 && birthDateEpoch > 0 && calorieTarget > 0
    }

    private var missingDataMessage: String {
        var parts: [String] = []
        if heightCm <= 0 { parts.append("height") }
        if weightKg <= 0 { parts.append("current weight") }
        if birthDateEpoch <= 0 { parts.append("date of birth") }
        if calorieTarget <= 0 { parts.append("calorie goal") }
        return "Enter your " + parts.joined(separator: ", ") + " in Settings to run the forecast."
    }

    private var userForecastSeries: WeightLossForecastSimulator.Series? {
        seriesList.first { $0.activityLevel == userActivityLevel }
    }

    @ViewBuilder
    private var summarySection: some View {
        Section {
            LabeledContent("Calorie target", value: "\(Int(calorieTarget.rounded())) kcal/day")
            LabeledContent("From", value: formatMassKg(weightKg))
            LabeledContent("To", value: formatMassKg(targetWeightKg))
            if let loss = lossDescriptionKg {
                LabeledContent("To lose", value: loss)
            }

            if let userSeries = userForecastSeries {
                Group {
                    switch userSeries.outcome {
                    case .reachedTarget(let days):
                        LabeledContent("At your activity (\(userActivityLevel.displayName))") {
                            Text(formatDuration(days: days))
                                .multilineTextAlignment(.trailing)
                        }
                    case .plateau(let lastDay, let w):
                        LabeledContent("At your activity (\(userActivityLevel.displayName))") {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Not reached in \(formatDuration(days: lastDay))")
                                Text("Plateau ~\(formatMassKg(w))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    case .noDeficitAtStart:
                        LabeledContent("At your activity") {
                            Text("No deficit at current weight")
                                .foregroundStyle(.orange)
                                .multilineTextAlignment(.trailing)
                        }
                    case .invalidInputs, .targetNotBelowCurrent:
                        EmptyView()
                    }
                }
            }
        } header: {
            Text("Summary")
        } footer: {
            Text(
                "Each curve assumes you eat your calorie target every day and that activity stays the same while mass changes. BMR is recomputed daily (Mifflin–St Jeor); TDEE is BMR × activity multiplier."
            )
            .font(.footnote)
        }
    }

    private var lossDescriptionKg: String? {
        guard weightKg > targetWeightKg else { return nil }
        let kg = weightKg - targetWeightKg
        if isMetric {
            return String(format: "%.1f kg", kg)
        }
        let lb = kg * 2.20462
        return String(format: "%.1f lb", lb)
    }

    @ViewBuilder
    private var chartSection: some View {
        Section {
            toggleRow

            if chartPoints.isEmpty {
                Text("Turn on at least one activity level to see the chart.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(chartPoints) { point in
                    LineMark(
                        x: .value("Day", point.day),
                        y: .value("Weight", displayWeight(fromKg: point.weightKg))
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(by: .value("Level", point.activityLevel.displayName))
                }
                .chartForegroundStyleScale(domain: chartDomainNames, range: chartColors)
                .frame(height: 260)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5))
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxisLabel("Days")
                .chartYAxisLabel(isMetric ? "kg" : "lb", position: .leading)
                .chartLegend(.hidden)
                .accessibilityLabel("Forecast weight by day for each activity level")
            }
        } header: {
            Text("Projected weight")
        }
    }

    private var chartDomainNames: [String] {
        UserProfile.ActivityLevel.allCases.map(\.displayName)
    }

    private var chartColors: [Color] {
        [
            .gray,
            .teal,
            .blue,
            .purple,
            .orange
        ]
    }

    private var toggleRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(UserProfile.ActivityLevel.allCases, id: \.self) { level in
                    Button {
                        if visibleActivities.contains(level) {
                            if visibleActivities.count > 1 {
                                visibleActivities.remove(level)
                            }
                        } else {
                            visibleActivities.insert(level)
                        }
                    } label: {
                        Text(level.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(visibleActivities.contains(level) ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var disclaimerSection: some View {
        Section {
            Text("This is a mathematical illustration, not medical advice. Real progress varies with water retention, muscle gain, logging accuracy, and metabolic adaptation.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var activityLegendSection: some View {
        Section {
            ForEach(UserProfile.ActivityLevel.allCases, id: \.self) { level in
                VStack(alignment: .leading, spacing: 6) {
                    Text(level.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(level.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(level.forecastExplanation)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("What each activity level means")
        } footer: {
            Text("PAL (physical activity level) labels are fuzzy. Pick the tier that best matches a typical week, not your hardest training day.")
                .font(.footnote)
        }
    }

    private func displayWeight(fromKg kg: Double) -> Double {
        isMetric ? kg : kg * 2.20462
    }

    private func formatMassKg(_ kg: Double) -> String {
        if isMetric {
            return String(format: "%.1f kg", kg)
        }
        return String(format: "%.1f lb", kg * 2.20462)
    }

    private func formatDuration(days: Int) -> String {
        guard days > 0 else { return "Same day" }
        if days < 14 {
            return "\(days) days"
        }
        if days < 120 {
            let w = (Double(days) / 7).rounded()
            return "~\(Int(w)) weeks (\(days) days)"
        }
        let m = Double(days) / 30.437
        if m < 24 {
            return String(format: "~%.1f months (%d days)", m, days)
        }
        let y = Double(days) / 365.25
        return String(format: "~%.1f years (%d days)", y, days)
    }
}

private struct ForecastChartPoint: Identifiable {
    let day: Int
    let weightKg: Double
    let activityLevel: UserProfile.ActivityLevel

    var id: String { "\(activityLevel.rawValue)-\(day)" }

    init(day: Int, weightKg: Double, activityLevel: UserProfile.ActivityLevel) {
        self.day = day
        self.weightKg = weightKg
        self.activityLevel = activityLevel
    }
}

#Preview {
    NavigationStack {
        WeightLossForecastView()
    }
}
