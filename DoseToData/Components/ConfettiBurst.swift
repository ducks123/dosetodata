import SwiftUI

/// A one-shot burst of confetti that plays whenever `trigger` changes to a non-nil value.
/// Uses `Canvas` + `TimelineView(.animation)` for cheap per-frame drawing.
struct ConfettiBurst: View {
    let trigger: UUID?

    @State private var activeBurst: Burst? = nil

    private static let colors: [Color] = [
        Color(red: 0.95, green: 0.30, blue: 0.37), // red
        Color(red: 0.98, green: 0.57, blue: 0.20), // orange
        Color(red: 0.98, green: 0.82, blue: 0.22), // yellow
        Color(red: 0.40, green: 0.78, blue: 0.42), // green
        Color(red: 0.30, green: 0.65, blue: 0.95), // blue
        Color(red: 0.64, green: 0.40, blue: 0.90), // purple
        Color(red: 0.96, green: 0.52, blue: 0.78)  // pink
    ]

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: activeBurst == nil)) { context in
                Canvas { ctx, size in
                    guard let burst = activeBurst else { return }
                    let elapsed = context.date.timeIntervalSince(burst.startTime)
                    if elapsed > burst.totalDuration { return }

                    for particle in burst.particles {
                        draw(particle: particle, elapsed: elapsed, burst: burst, context: ctx, size: size)
                    }
                }
            }
            .onChange(of: trigger) { _, newValue in
                guard newValue != nil else { return }
                start(in: geo.size)
            }
            .onChange(of: activeBurst) { _, burst in
                guard let burst else { return }
                // Schedule cleanup after the burst completes so the TimelineView can pause.
                let deadline = DispatchTime.now() + burst.totalDuration + 0.05
                DispatchQueue.main.asyncAfter(deadline: deadline) {
                    if activeBurst?.id == burst.id {
                        activeBurst = nil
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func start(in size: CGSize) {
        let particleCount = 70
        let now = Date()
        let particles: [Particle] = (0..<particleCount).map { _ in
            // Launch from a band near the top, so the burst reads as "from above".
            let originX = size.width * CGFloat.random(in: 0.15...0.85)
            let originY = size.height * CGFloat.random(in: 0.05...0.25)
            // Angle spans upward half-circle: -π (left) through -π/2 (up) to 0 (right).
            let angle = CGFloat.random(in: (-.pi)...0)
            let speed = CGFloat.random(in: 280...560)
            let vx = cos(angle) * speed
            let vy = sin(angle) * speed // negative -> up in screen coords
            return Particle(
                origin: CGPoint(x: originX, y: originY),
                velocity: CGVector(dx: vx, dy: vy),
                color: Self.colors.randomElement() ?? .pink,
                size: CGFloat.random(in: 6...10),
                shape: Bool.random() ? .square : .circle,
                rotation: CGFloat.random(in: 0...(2 * .pi)),
                spin: CGFloat.random(in: -6...6)
            )
        }
        activeBurst = Burst(
            id: UUID(),
            startTime: now,
            totalDuration: 2.0,
            fadeStart: 1.4,
            gravity: 900,
            particles: particles
        )
    }

    private func draw(
        particle: Particle,
        elapsed: TimeInterval,
        burst: Burst,
        context: GraphicsContext,
        size: CGSize
    ) {
        let t = CGFloat(elapsed)
        let x = particle.origin.x + particle.velocity.dx * t
        let y = particle.origin.y + particle.velocity.dy * t + 0.5 * burst.gravity * t * t

        // Fade during the last fadeStart...totalDuration window.
        let opacity: Double = {
            if elapsed <= burst.fadeStart { return 1.0 }
            let remaining = burst.totalDuration - burst.fadeStart
            let into = elapsed - burst.fadeStart
            return max(0, 1.0 - into / remaining)
        }()

        var local = context
        local.opacity = opacity
        local.translateBy(x: x, y: y)
        local.rotate(by: .radians(Double(particle.rotation + particle.spin * t)))

        let rect = CGRect(
            x: -particle.size / 2,
            y: -particle.size / 2,
            width: particle.size,
            height: particle.size
        )
        switch particle.shape {
        case .square:
            local.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(particle.color))
        case .circle:
            local.fill(Path(ellipseIn: rect), with: .color(particle.color))
        }
    }
}

private struct Burst: Equatable {
    let id: UUID
    let startTime: Date
    let totalDuration: TimeInterval
    let fadeStart: TimeInterval
    let gravity: CGFloat
    let particles: [Particle]

    static func == (lhs: Burst, rhs: Burst) -> Bool { lhs.id == rhs.id }
}

private struct Particle {
    let origin: CGPoint
    let velocity: CGVector
    let color: Color
    let size: CGFloat
    let shape: ParticleShape
    let rotation: CGFloat
    let spin: CGFloat
}

private enum ParticleShape {
    case square
    case circle
}

