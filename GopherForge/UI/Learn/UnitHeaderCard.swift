import SwiftUI

/// The card at the top of a unit: what it is for, and how far through it you
/// are, in a shape you can read before you read a word of it.
struct UnitHeaderCard: View {
    let unit: CourseUnit
    let done: Int
    let total: Int

    private var fraction: Double {
        total == 0 ? 0 : Double(done) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                UnitProgressRing(fraction: fraction, symbol: CourseUnitStyle.symbol(for: unit.id))
                    .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 3) {
                    Text(unit.title).font(.headline)
                    Text("\(done) of \(total) lessons")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            Text(unit.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: CourseUnitStyle.gradient(for: unit.id),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

/// A ring around the unit's symbol. The ring is the progress; the symbol is
/// which unit it is, so a glance answers both.
struct UnitProgressRing: View {
    let fraction: Double
    let symbol: String

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.12), lineWidth: 5)
            Circle()
                .trim(from: 0, to: max(0.001, fraction))
                .stroke(GopherForgeTheme.ember, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(GopherForgeTheme.ember)
        }
        .accessibilityHidden(true)
    }
}

/// One row for a drill or a quiz.
struct PracticeRow: View {
    let title: String
    let detail: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(tint)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
