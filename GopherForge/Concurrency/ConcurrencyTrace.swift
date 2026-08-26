import Foundation

/// An ordered trace plus the state a reader needs to make sense of it.
struct ConcurrencyTrace: Equatable, Sendable {
    let events: [ConcurrencyEvent]

    init(events: [ConcurrencyEvent]) {
        self.events = events.sorted { $0.sequence < $1.sequence }
    }

    var actors: [String] {
        var seen: [String] = []
        for event in events where !seen.contains(event.actor) {
            seen.append(event.actor)
        }
        return seen
    }

    var channels: [String] {
        var seen: [String] = []
        let channelKinds: Set<ConcurrencyEvent.Kind> = [.send, .receive, .channelClosed]
        for event in events where channelKinds.contains(event.kind) {
            if let subject = event.subject, !seen.contains(subject) { seen.append(subject) }
        }
        return seen
    }

    /// Goroutines that blocked and never produced another event afterwards.
    /// This is the signal the lab explains: a goroutine that goes quiet while
    /// blocked never came back.
    var stuckActors: [String] {
        var blockedAt: [String: Int] = [:]
        var lastEvent: [String: Int] = [:]
        for event in events {
            lastEvent[event.actor] = event.sequence
            if event.isBlocking {
                blockedAt[event.actor] = event.sequence
            } else if event.kind == .goroutineFinished {
                blockedAt[event.actor] = nil
            }
        }
        return blockedAt
            .filter { actor, sequence in lastEvent[actor] == sequence }
            .keys
            .sorted()
    }

    /// Channels that were sent on after being closed, ordered as they happened.
    var sendsAfterClose: [ConcurrencyEvent] {
        var closed: Set<String> = []
        var offenders: [ConcurrencyEvent] = []
        for event in events {
            guard let subject = event.subject else { continue }
            switch event.kind {
            case .channelClosed: closed.insert(subject)
            case .send where closed.contains(subject): offenders.append(event)
            default: break
            }
        }
        return offenders
    }

    /// Running buffer occupancy per channel, for the visualisation.
    func bufferDepths(upTo sequence: Int) -> [String: Int] {
        var depths: [String: Int] = [:]
        for event in events where event.sequence <= sequence {
            guard let subject = event.subject else { continue }
            switch event.kind {
            case .send: depths[subject, default: 0] += 1
            case .receive: depths[subject, default: 0] -= 1
            default: break
            }
        }
        return depths
    }

    func events(for actor: String) -> [ConcurrencyEvent] {
        events.filter { $0.actor == actor }
    }
}
