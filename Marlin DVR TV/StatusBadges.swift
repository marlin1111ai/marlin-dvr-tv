//
//  StatusBadges.swift
//  Marlin DVR TV
//
//  Pass 137: the status badges and lines as shared views on Pass 136's tokens (REA report §5.1
//  item 14) — wherever the server already gives the fact. The Guide, the airing sheet and the
//  Player's panel keep their own drawings (out of scope).
//
//  What the server gives: `new`, `live`, `finale` and a rating on a programme, `hd` on a
//  channel, `watched` and `inProgress` on a recording, and the schedule's seven statuses. What it
//  does not give, so no badge draws it: a premiere flag that is ever set (Pass 81 — On Later's
//  Premieres pill derives one, and its card draws that), season against series premiere,
//  "interrupted / stopped early / started late" on a finished recording, a removal date for a
//  trashed recording, Dolby or 4K.
//

import SwiftUI

/// The small uppercase tags — NEW, LIVE, PREMIERE, FINALE, HD — drawn as `TagChip`s (frame 5c).
enum StatusTag: String, Hashable {
    case new = "New", live = "Live", premiere = "Premiere", finale = "Finale", hd = "HD"

    /// The programme's own flags, in the order the On Now card has drawn them since Pass 6, a
    /// derived premiere where the caller has one (On Later's rule) in place of the flag, and HD
    /// from the channel.
    static func tags(for program: Program?, premiere: Bool? = nil, hd: Bool = false) -> [StatusTag] {
        var out: [StatusTag] = []
        if let p = program {
            if p.new == true { out.append(.new) }
            if p.live == true { out.append(.live) }
            if premiere ?? (p.premiere == true) { out.append(.premiere) }
            if p.finale == true { out.append(.finale) }
        }
        if hd { out.append(.hd) }
        return out
    }
}

/// The tags in a row; nothing when there are none. Each keeps its own width, so a narrow card
/// truncates the text beside them rather than breaking a tag mid-word (seen on On Now with the
/// sidebar open).
struct StatusTagRow: View {
    let tags: [StatusTag]

    var body: some View {
        ForEach(tags, id: \.self) { TagChip(text: $0.rawValue).fixedSize() }
    }
}

/// A state with its dot — "● Recording", "● Scheduled", "● Recording now" — in the pair's ink,
/// and as a capsule on the pair's tint when `capsule` is set (the On Later card's chip).
struct StateBadge: View {
    let text: String
    let pair: Nocturne.Semantic.Pair
    var capsule = false

    var body: some View {
        Text("● \(text)")
            .font(.nocturne(.meta))
            .foregroundStyle(pair.text)
            .padding(.vertical, capsule ? 6 : 0)
            .padding(.horizontal, capsule ? 16 : 0)
            .background(capsule ? pair.background : .clear, in: Capsule())
    }
}

/// A count on a card — "3 new" — the accent capsule the poster card has drawn since Pass 6.
struct CountBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.nocturne(Nocturne.TextSize.floor, .semibold))
            .foregroundStyle(Nocturne.bg)
            .padding(.vertical, 4)
            .padding(.horizontal, 12)
            .background(Nocturne.accent, in: Capsule())
    }
}
