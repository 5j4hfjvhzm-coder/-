import Foundation

/// 위키낱말사전 태그 → 한국어 배지. scripts/build_dict.py 의 KEEP_TAGS 와 같은 목록을 유지할 것
/// (scripts/test_build_dict.py 가 확인한다).
let tagKorean: [String: String] = [
    "slang": "속어",
    "informal": "비격식",
    "colloquial": "구어",
    "idiomatic": "관용",
    "vulgar": "비속어",
    "offensive": "모욕적",
    "derogatory": "경멸",
    "pejorative": "경멸",
    "euphemistic": "완곡",
    "humorous": "익살",
    "ironic": "반어",
    "figuratively": "비유",
    "metaphoric": "비유",
    "formal": "격식",
    "literary": "문어",
    "archaic": "고어",
    "obsolete": "폐어",
    "dated": "예스러움",
    "rare": "드묾",
    "Internet": "인터넷",
    "Internet-slang": "인터넷 속어",
    "US": "미국",
    "UK": "영국",
    "British": "영국",
    "Australia": "호주",
    "transitive": "타동사",
    "intransitive": "자동사",
    "countable": "가산",
    "uncountable": "불가산",
    "phrasal-verb": "구동사",
]

/// 눈에 띄게(빨간색) 표시할 태그
let strongTags: Set<String> = ["slang", "vulgar", "offensive", "derogatory", "pejorative", "Internet-slang"]

struct TagLabel: Equatable, Hashable {
    let tag: String
    let label: String
    let strong: Bool
}

func tagLabels(_ tags: [String]) -> [TagLabel] {
    var seen = Set<String>()
    var out: [TagLabel] = []
    for t in tags {
        guard let label = tagKorean[t], seen.insert(label).inserted else { continue }
        out.append(TagLabel(tag: t, label: label, strong: strongTags.contains(t)))
    }
    // 속어 계열 먼저 (그 안에서는 원래 순서)
    return out.filter(\.strong) + out.filter { !$0.strong }
}
