import SwiftUI

struct CompeteWelcomeView: View {
    let onStartBoard: () -> Void
    let onJoinBoard: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)

            VStack(spacing: 14) {
                Image(systemName: StepReceiptSymbol.competitionTab)
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(Color.stepAccent)
                    .frame(width: 88, height: 88)
                    .background(
                        LinearGradient(
                            colors: [Color.stepAccent.opacity(0.18), Color.stepEnergy.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                Text("Compete together")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.stepInk)
                    .multilineTextAlignment(.center)

                Text("Start a household board for you and your partner. Only daily totals sync — steps, distance, burn, and workout minutes.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)

            VStack(spacing: 12) {
                Button(action: onStartBoard) {
                    Label("Start a household board", systemImage: "person.2.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.stepAccent)
                .controlSize(.large)
                .accessibilityIdentifier("compete-welcome-start")

                Button(action: onJoinBoard) {
                    Label("Join with code", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.stepDistance)
                .controlSize(.large)
                .accessibilityIdentifier("compete-welcome-join")
            }

            Label("Privacy-safe: aggregate daily totals only", systemImage: "lock.shield")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.stepMuted)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(20)
        .accessibilityIdentifier("compete-welcome-screen")
        .accessibilityElement(children: .contain)
    }
}
