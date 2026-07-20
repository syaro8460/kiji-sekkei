enum DraftSortOrder: String, CaseIterable {
    case updatedNewest
    case updatedOldest
    case titleAscending
    case titleDescending

    var title: String {
        switch self {
        case .updatedNewest:
            return "更新日（新しい順）"

        case .updatedOldest:
            return "更新日（古い順）"

        case .titleAscending:
            return "タイトル（昇順）"

        case .titleDescending:
            return "タイトル（降順）"
        }
    }
}
