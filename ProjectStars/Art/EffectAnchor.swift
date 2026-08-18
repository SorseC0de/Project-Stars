//
//  EffectAnchor.swift
//  Project Stars
//
//  Where an effect's frame sits against the square it plays on.
//

import Foundation

/// How a strip is placed over its square.
///
/// See `EffectSprite.anchor` for which is which and why it is a property of the
/// effect rather than a number at the site that plays it.
enum EffectAnchor {

    /// The frame's centre on the square's centre. Something happening *at* a
    /// place.
    case centred

    /// The frame's bottom edge on the square's centre, so the art rises from
    /// it. Something that belongs *over* a place.
    case standing
}
