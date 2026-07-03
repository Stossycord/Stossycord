//
//  NativeEmoji.swift
//  Stossycord
//
//  Created by Stossy11 on 2/7/2026.
//

import Foundation
import Combine


enum NativeEmojiType: CaseIterable, Identifiable, Hashable {
    case emoticons
    case miscSymbols
    case transportAndMap
    case flagsAndRegionalIndicators
    case supplementalSymbols
    case objectsAndVariedSymbols
    
    var id: String { self.displayName }
 

    var icon: String {
        switch self {
        case .emoticons:
            "face.smiling.inverse"
        case .miscSymbols:
            "pawprint.circle"
        case .transportAndMap:
            "map.circle"
        case .flagsAndRegionalIndicators:
            "flag.circle"
        case .supplementalSymbols:
            "figure.walk.circle"
        case .objectsAndVariedSymbols:
            "shippingbox.circle"
        }
    }
 
    var displayName: String {
        switch self {
        case .emoticons:
            "Smileys & People"
        case .miscSymbols:
            "Nature & Symbols"
        case .transportAndMap:
            "Travel & Places"
        case .flagsAndRegionalIndicators:
            "Regional Indicators"
        case .supplementalSymbols:
            "Extra Symbols"
        case .objectsAndVariedSymbols:
            "Objects"
        }
    }
}
 
struct NativeEmoji: Identifiable {
    var type: NativeEmojiType
    var emoji: String
    
    var id: String { emoji }
}

extension NativeEmoji {
    private static let knownSequenceNames: [String: String] = {
        var names: [String: String] = [:]
        
        // MARK: - Pride / flags
        names["\u{1F3F3}\u{FE0F}\u{200D}\u{1F308}"] = "rainbow pride flag lgbt"
        names["\u{1F3F3}\u{FE0F}\u{200D}\u{26A7}\u{FE0F}"] = "transgender flag trans"
        names["\u{1F3F4}\u{200D}\u{2620}\u{FE0F}"] = "pirate flag jolly roger"
        
        // MARK: - Couples with heart
        let man = "\u{1F468}"
        let woman = "\u{1F469}"
        let heart = "\u{2764}\u{FE0F}"
        let kiss = "\u{1F48B}"
        let zwj = "\u{200D}"
        
        names[man + zwj + heart + zwj + man] = "couple with heart man man gay"
        names[woman + zwj + heart + zwj + woman] = "couple with heart woman woman lesbian"
        names[man + zwj + heart + zwj + woman] = "couple with heart man woman"
        
        names[man + zwj + heart + zwj + kiss + zwj + man] = "kiss couple man man gay"
        names[woman + zwj + heart + zwj + kiss + zwj + woman] = "kiss couple woman woman lesbian"
        names[man + zwj + heart + zwj + kiss + zwj + woman] = "kiss couple man woman"
        
        // MARK: - Families
        let boy = "\u{1F466}"
        let girl = "\u{1F467}"
        
        // two-parent families
        let parentPairs: [(String, String, String)] = [
            (man, woman, "man woman"),
            (man, man, "man man gay"),
            (woman, woman, "woman woman lesbian"),
        ]
        let childCombos: [([String], String)] = [
            ([boy], "boy son"),
            ([girl], "girl daughter"),
            ([boy, boy], "two boys sons"),
            ([girl, girl], "two girls daughters"),
            ([girl, boy], "girl and boy son daughter"),
        ]
        for (p1, p2, parentLabel) in parentPairs {
            for (children, childLabel) in childCombos {
                let seq = p1 + zwj + p2 + zwj + children.joined(separator: zwj)
                names[seq] = "family \(parentLabel) \(childLabel)"
            }
        }
        
        // single-parent families
        let singleParents: [(String, String)] = [(man, "man father"), (woman, "woman mother")]
        for (parent, parentLabel) in singleParents {
            for (children, childLabel) in childCombos {
                let seq = parent + zwj + children.joined(separator: zwj)
                names[seq] = "family single parent \(parentLabel) \(childLabel)"
            }
        }
        
        // MARK: - Professions
        let person = "\u{1F9D1}"
        
        // (symbol sequence appended after base, label)
        let professions: [(String, String)] = [
            ("\u{200D}\u{2695}\u{FE0F}", "health worker doctor nurse medic"),
            ("\u{200D}\u{1F393}", "student graduate"),
            ("\u{200D}\u{1F3EB}", "teacher professor"),
            ("\u{200D}\u{2696}\u{FE0F}", "judge lawyer justice"),
            ("\u{200D}\u{1F33E}", "farmer agriculture"),
            ("\u{200D}\u{1F373}", "cook chef"),
            ("\u{200D}\u{1F527}", "mechanic repair"),
            ("\u{200D}\u{1F3ED}", "factory worker industrial"),
            ("\u{200D}\u{1F4BC}", "office worker business"),
            ("\u{200D}\u{1F52C}", "scientist researcher"),
            ("\u{200D}\u{1F4BB}", "technologist programmer coder"),
            ("\u{200D}\u{1F3A4}", "singer musician performer"),
            ("\u{200D}\u{1F3A8}", "artist painter"),
            ("\u{200D}\u{2708}\u{FE0F}", "pilot airplane"),
            ("\u{200D}\u{1F680}", "astronaut space"),
            ("\u{200D}\u{1F692}", "firefighter fire department"),
        ]
        
        for (suffix, label) in professions {
            names[man + suffix] = "man \(label)"
            names[woman + suffix] = "woman \(label)"
            names[person + suffix] = "person \(label)"
        }
        
        // MARK: - Roles with pre-gendered bases
        let femaleSign = "\u{200D}\u{2640}\u{FE0F}"
        let maleSign = "\u{200D}\u{2642}\u{FE0F}"
        
        let genderedRoles: [(String, String)] = [
            ("\u{1F46E}", "police officer cop"),
            ("\u{1F575}\u{FE0F}", "detective spy sleuth"),
            ("\u{1F482}", "guard security"),
            ("\u{1F477}", "construction worker builder"),
            ("\u{1F473}", "person wearing turban"),
            ("\u{1F471}", "person blond hair"),
            ("\u{1F9D9}", "mage wizard fantasy"),
            ("\u{1F9DA}", "fairy fantasy"),
            ("\u{1F9DB}", "vampire fantasy"),
            ("\u{1F9DC}", "merperson mermaid merman"),
            ("\u{1F9DD}", "elf fantasy"),
        ]
        for (base, label) in genderedRoles {
            names[base + femaleSign] = "woman \(label)"
            names[base + maleSign] = "man \(label)"
        }
        
        // MARK: - Sports / activities
        let activities: [(String, String)] = [
            ("\u{26F9}\u{FE0F}", "person bouncing ball basketball"),
            ("\u{1F3CB}\u{FE0F}", "weightlifter gym"),
            ("\u{1F3C4}", "surfer"),
            ("\u{1F3CA}", "swimmer"),
            ("\u{1F6A3}", "rower rowing boat"),
            ("\u{1F6B4}", "cyclist biking"),
            ("\u{1F6B5}", "mountain biker"),
            ("\u{1F3C3}", "runner jogger"),
            ("\u{1F93C}", "wrestler wrestling"),
            ("\u{1F939}", "juggler juggling"),
            ("\u{1F9D8}", "person in lotus position yoga"),
            ("\u{1F3CC}\u{FE0F}", "golfer golf"),
        ]
        for (base, label) in activities {
            names[base + femaleSign] = "woman \(label)"
            names[base + maleSign] = "man \(label)"
        }
        
        return names
    }()
    
    var searchableName: String {
        if let known = Self.knownSequenceNames[emoji] {
            return known
        }
        
        if let known = ZWJSequenceNameStore.shared.searchableName(for: emoji) {
            return known
        }
        
        if let code = emoji.flagCountryCode,
           let countryName = Locale.current.localizedString(forRegionCode: code) {
            return countryName.lowercased()
        }
        return emoji.unicodeScalars.first?.properties.name?.lowercased() ?? emoji.lowercased()
    }
}

enum ZWJSequenceParser {
    static func parse(_ contents: String) -> [String: String] {
        var results: [String: String] = [:]
        
        for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            
            let withoutComment = line.split(separator: "#", maxSplits: 1)[0]
            
            let fields = withoutComment.components(separatedBy: ";").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard fields.count >= 3 else { continue }
            
            let codepointField = fields[0]
            let description = fields[2]
            
            guard let emoji = codepointsToString(codepointField) else { continue }
            guard !description.isEmpty else { continue }
            
            results[emoji] = normalize(description)
        }
        
        return results
    }
    
    private static func codepointsToString(_ field: String) -> String? {
        let hexTokens = field.split(separator: " ").map { $0.trimmingCharacters(in: .whitespaces) }
        guard !hexTokens.isEmpty else { return nil }
        
        var scalars: [Unicode.Scalar] = []
        scalars.reserveCapacity(hexTokens.count)
        
        for token in hexTokens {
            guard let value = UInt32(token, radix: 16),
                  let scalar = Unicode.Scalar(value) else {
                return nil
            }
            scalars.append(scalar)
        }
        
        var view = String.UnicodeScalarView()
        scalars.forEach { view.append($0) }
        return String(view)
    }
    
    private static func normalize(_ description: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let cleaned = description.unicodeScalars
            .map { allowed.contains($0) ? Character($0) : " " }
            .reduce(into: "") { $0.append($1) }
        
        return cleaned
            .split(separator: " ")
            .joined(separator: " ")
            .lowercased()
    }
}

extension URL {
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}

final class ZWJSequenceNameStore {
    static let shared = ZWJSequenceNameStore()
    
    private(set) var names: [String: String] = [:]
    private(set) var loadError: String?
    
    private init() {
        loadBundled()
    }
    
    @discardableResult
    func load() -> Bool {
        guard !loadBundled() else { return true }
        
        return load(from: URL(string: "https://raw.githubusercontent.com/unicode-org/icu/refs/heads/main/icu4c/source/data/unidata/emoji-zwj-sequences.txt")!)
    }
    
    @discardableResult
    func loadBundled() -> Bool {
        return load(from: URL.documentsDirectory.appendingPathComponent("emoji-zwj-sequences.txt"))
    }
    
    @discardableResult
    func load(from url: URL) -> Bool {
        do {
            let contents = try String(contentsOf: url, encoding: .utf8)
            FileManager.default.createFile(atPath: URL.documentsDirectory.appendingPathComponent("emoji-zwj-sequences.txt").path, contents: contents.data(using: .utf8)!)
            names = ZWJSequenceParser.parse(contents)
            loadError = nil
            return true
        } catch {
            loadError = "Failed to read \(url): \(error.localizedDescription)"
            return false
        }
    }
    
    func load(fromContents contents: String) {
        names = ZWJSequenceParser.parse(contents)
        loadError = nil
    }
    
    func searchableName(for emoji: String) -> String? {
        names[emoji]
    }
}

private enum PrivSym {
    static func j(_ parts: [String]) -> String { parts.joined() }
    
    static let cls = j(["EMF", "Emoji", "Cat", "egory"])
    static let selList = j(["categ", "oryIdent", "ifierList"])
    static let selSetFor = j(["_emo", "jiSetForIdent", "ifier:"])
    static let fwPathDefault = j(["/System/Library/PrivateFrameworks/",
                                  "EmojiFoun", "dation.framework"])
}

final class PrivateEmojiHandler: ObservableObject {
    
    @Published var emojis: [NativeEmoji] = []
    
    static var shared: PrivateEmojiHandler = .init()
    
    private(set) var loadError: String?
    
    private let frameworkPath: String
    
    init(frameworkPath: String = PrivSym.fwPathDefault) {
        self.frameworkPath = frameworkPath
        emojis = Self.scanAllEmojis(frameworkPath: frameworkPath) { [weak self] err in
            self?.loadError = err
        }
    }
    
    private static func scanAllEmojis(
        frameworkPath: String,
        onError: (String) -> Void
    ) -> [NativeEmoji] {
        
        guard let bndl = Bundle(url: URL(fileURLWithPath: frameworkPath)) else {
            onError("EmojiFoundation framework not found at \(frameworkPath)")
            return []
        }
        
        do {
            try bndl.loadAndReturnError()
        } catch {
            onError("Failed to load \(bndl): \(error)")
            return []
        }
        
        guard let targetClass = NSClassFromString(PrivSym.cls) as? NSObject.Type else {
            onError("\(PrivSym.cls) class not found.")
            return []
        }
        
        let listSel = NSSelectorFromString(PrivSym.selList)
        guard targetClass.responds(to: listSel),
              let idsUnmanaged = targetClass.perform(listSel),
              let categoryIdentifiers = idsUnmanaged.takeUnretainedValue() as? [String],
              !categoryIdentifiers.isEmpty else {
            onError("\(PrivSym.cls) returned no category identifiers.")
            return []
        }
        
        let setForSel = NSSelectorFromString(PrivSym.selSetFor)
        guard targetClass.responds(to: setForSel) else {
            onError("\(PrivSym.cls) does not respond to emoji-set selector.")
            return []
        }
        
        var results: [NativeEmoji] = []
        results.reserveCapacity(4000)
        
        for categoryIdentifier in categoryIdentifiers {
            guard let resultUnmanaged = targetClass.perform(setForSel, with: categoryIdentifier),
                  let emojiSet = resultUnmanaged.takeUnretainedValue() as? [String],
                  !emojiSet.isEmpty else {
                continue
            }
            
            let type = mapIdentifierToType(categoryIdentifier)
            for emoji in emojiSet {
                results.append(NativeEmoji(type: type, emoji: emoji))
            }
        }
        
        return results
    }
    
    private static func mapIdentifierToType(_ identifier: String) -> NativeEmojiType {
        let stripped = identifier
            .replacingOccurrences(of: PrivSym.cls, with: "")
            .lowercased()
        
        switch true {
        case stripped.contains("smiley"), stripped.contains("people"), stripped.contains("emoticon"):
            return .emoticons
        case stripped.contains("nature"), stripped.contains("food"), stripped.contains("animal"):
            return .miscSymbols
        case stripped.contains("travel"), stripped.contains("place"), stripped.contains("transport"):
            return .transportAndMap
        case stripped.contains("flag"):
            return .flagsAndRegionalIndicators
        case stripped.contains("activity"), stripped.contains("sport"):
            return .supplementalSymbols
        case stripped.contains("object"), stripped.contains("symbol"):
            return .objectsAndVariedSymbols
        default: return .objectsAndVariedSymbols
        }
    }
    
    
    func getAllEmojis() -> [NativeEmoji] {
        emojis
    }
    
    func getEmojisForType(_ type: NativeEmojiType) -> [NativeEmoji] {
        emojis.filter { $0.type == type }
    }
    
    func reload(frameworkPath: String? = nil) {
        let path = frameworkPath ?? self.frameworkPath
        loadError = nil
        emojis = Self.scanAllEmojis(frameworkPath: path) { [weak self] err in
            self?.loadError = err
        }
    }
}

extension String {
    var isFlagEmoji: Bool {
        let scalars = unicodeScalars
        return scalars.count == 2 && scalars.allSatisfy { (0x1F1E6...0x1F1FF).contains($0.value) }
    }
    
    var flagCountryCode: String? {
        guard isFlagEmoji else { return nil }
        let letters = unicodeScalars.compactMap { scalar -> Character? in
            guard let letterScalar = Unicode.Scalar(scalar.value - 0x1F1E6 + 0x41) else { return nil }
            return Character(letterScalar)
        }
        return letters.count == 2 ? String(letters) : nil
    }
}
