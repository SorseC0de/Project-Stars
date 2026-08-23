//
//  BenchStore.swift
//  Project Stars
//
//  Keeping a bench's knobs between builds.
//

import Foundation

#if DEBUG

/// Where a tuning bench keeps its values.
///
/// ## Why this is shared
///
/// Because there is more than one bench now, and the awkward parts of this are
/// the same for all of them: absence is not zero, a changed default has to beat
/// a stored value, and every knob has to be forgettable at once. Written out per
/// bench, the second copy is where the subtlety quietly goes missing.
///
/// A knob that resets on every rebuild is a knob you tune twice — once to find
/// the value, and once to get back to it after the next compile.
struct BenchStore {

    /// What this bench's keys are prefixed with.
    let prefix: String

    /// Bumped whenever a shipped default changes.
    ///
    /// Stored values otherwise win over new defaults for ever: a knob tuned to
    /// the old number reads back as that number, and the value written in the
    /// source is never seen again on any machine that has touched it once. On a
    /// bump every knob here is forgotten.
    let vintage: Int

    /// Every key this bench owns, so a reset can clear the lot.
    let names: [String]

    func value(_ name: String, _ fallback: Double) -> Double {
        checkVintage()
        let store = UserDefaults.standard
        // `double(forKey:)` answers 0 for a key it has never seen, which is a
        // real value for most knobs — so absence has to be asked about rather
        // than inferred from what comes back.
        guard store.object(forKey: prefix + name) != nil else { return fallback }
        return store.double(forKey: prefix + name)
    }

    func flag(_ name: String, _ fallback: Bool) -> Bool {
        value(name, fallback ? 1 : 0) > 0.5
    }

    func set(_ name: String, _ value: Double) {
        UserDefaults.standard.set(value, forKey: prefix + name)
    }

    func set(_ name: String, _ value: Bool) {
        set(name, value ? 1 : 0)
    }

    func words(_ name: String, _ fallback: String) -> String {
        checkVintage()
        return UserDefaults.standard.string(forKey: prefix + name) ?? fallback
    }

    func set(_ name: String, _ value: String) {
        UserDefaults.standard.set(value, forKey: prefix + name)
    }

    /// Forgets everything, so the next read takes the shipped default.
    func forget() {
        let store = UserDefaults.standard
        for name in names { store.removeObject(forKey: prefix + name) }
    }

    private func checkVintage() {
        let store = UserDefaults.standard
        guard store.integer(forKey: prefix + "vintage") != vintage else { return }
        forget()
        store.set(vintage, forKey: prefix + "vintage")
    }
}

#endif
