// MacStatusLand/MacStatusLand/Models/IconPreset.swift

import Foundation

/// 图标预设配置
struct IconPreset: Codable, Identifiable, Equatable {
    /// 唯一标识
    let id: UUID
    
    /// 预设名称
    var name: String
    
    /// 可见图标集合
    var visibleIcons: Set<String>
    
    /// 创建时间
    var createdAt: Date
    
    /// 初始化
    init(id: UUID = UUID(), name: String, visibleIcons: Set<String>, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.visibleIcons = visibleIcons
        self.createdAt = createdAt
    }
    
    /// 从当前状态创建预设
    static func fromCurrentState(name: String, allIcons: [IconItem]) -> IconPreset {
        let visibleIds = Set(allIcons.filter { !$0.isHidden }.map { $0.id })
        return IconPreset(name: name, visibleIcons: visibleIds)
    }
}
