// DO NOT EDIT.
// swift-format-ignore-file
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: dmView.proto
//
// For information on using the generated types, please see the documentation:
//   https://github.com/apple/swift-protobuf/

import Foundation
import SwiftProtobuf

// If the compiler emits an error on this type, it is because this file
// was generated by a version of the `protoc` Swift plug-in that is
// incompatible with the version of SwiftProtobuf to which you are linking.
// Please ensure that you are building against the same version of the API
// that was used to generate this file.
fileprivate struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
    struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
    typealias Version = _2
}

/// 分段弹幕配置
struct DmSegConfig {
    // SwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
    // methods supported on all messages.

    /// 分段时间 ms
    var pageSize: Int64 = 0

    /// 最大分页数？
    var total: Int64 = 0

    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}
}

/// 云屏蔽配置信息
struct DanmakuFlagConfig {
    // SwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
    // methods supported on all messages.

    /// 云屏蔽等级
    var recFlag: Int32 = 0

    /// 云屏蔽文案
    var recText: String = .init()

    /// 云屏蔽开关
    var recSwitch: Int32 = 0

    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}
}

/// 互动弹幕条目
struct CommandDm {
    // SwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
    // methods supported on all messages.

    /// 弹幕id
    var id: Int64 = 0

    /// 视频cid
    var oid: Int64 = 0

    /// 发送者mid
    var mid: Int64 = 0

    /// 弹幕指令
    var command: String = .init()

    /// 弹幕文字
    var content: String = .init()

    /// 弹幕出现时间
    var progress: Int32 = 0

    /// 创建时间
    var ctime: String = .init()

    /// 发布时间
    var mtime: String = .init()

    /// 扩展json数据
    var extra: String = .init()

    /// 弹幕id str类型
    var idStr: String = .init()

    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}
}

/// 弹幕个人配置
struct DanmuWebPlayerConfig {
    // SwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
    // methods supported on all messages.

    /// 弹幕开关
    var dmSwitch: Bool {
        get { return _storage._dmSwitch }
        set { _uniqueStorage()._dmSwitch = newValue }
    }

    /// 智能云屏蔽
    var aiSwitch: Bool {
        get { return _storage._aiSwitch }
        set { _uniqueStorage()._aiSwitch = newValue }
    }

    /// 智能云屏蔽级别
    var aiLevel: Int32 {
        get { return _storage._aiLevel }
        set { _uniqueStorage()._aiLevel = newValue }
    }

    /// 屏蔽类型-顶部
    var blocktop: Bool {
        get { return _storage._blocktop }
        set { _uniqueStorage()._blocktop = newValue }
    }

    /// 屏蔽类型-滚动
    var blockscroll: Bool {
        get { return _storage._blockscroll }
        set { _uniqueStorage()._blockscroll = newValue }
    }

    /// 屏蔽类型-底部
    var blockbottom: Bool {
        get { return _storage._blockbottom }
        set { _uniqueStorage()._blockbottom = newValue }
    }

    /// 屏蔽类型-彩色
    var blockcolor: Bool {
        get { return _storage._blockcolor }
        set { _uniqueStorage()._blockcolor = newValue }
    }

    /// 屏蔽类型-特殊
    var blockspecial: Bool {
        get { return _storage._blockspecial }
        set { _uniqueStorage()._blockspecial = newValue }
    }

    /// 防挡弹幕（底部15%）
    var preventshade: Bool {
        get { return _storage._preventshade }
        set { _uniqueStorage()._preventshade = newValue }
    }

    /// 智能防挡弹幕（人像蒙版）
    var dmask: Bool {
        get { return _storage._dmask }
        set { _uniqueStorage()._dmask = newValue }
    }

    /// 弹幕不透明度
    var opacity: Float {
        get { return _storage._opacity }
        set { _uniqueStorage()._opacity = newValue }
    }

    /// 弹幕显示区域
    var dmarea: Int32 {
        get { return _storage._dmarea }
        set { _uniqueStorage()._dmarea = newValue }
    }

    /// 弹幕速度
    var speedplus: Float {
        get { return _storage._speedplus }
        set { _uniqueStorage()._speedplus = newValue }
    }

    /// 字体大小
    var fontsize: Float {
        get { return _storage._fontsize }
        set { _uniqueStorage()._fontsize = newValue }
    }

    /// 跟随屏幕缩放比例
    var screensync: Bool {
        get { return _storage._screensync }
        set { _uniqueStorage()._screensync = newValue }
    }

    /// 根据播放倍速调整速度
    var speedsync: Bool {
        get { return _storage._speedsync }
        set { _uniqueStorage()._speedsync = newValue }
    }

    /// 字体类型
    var fontfamily: String {
        get { return _storage._fontfamily }
        set { _uniqueStorage()._fontfamily = newValue }
    }

    /// 粗体
    var bold: Bool {
        get { return _storage._bold }
        set { _uniqueStorage()._bold = newValue }
    }

    /// 描边类型
    var fontborder: Int32 {
        get { return _storage._fontborder }
        set { _uniqueStorage()._fontborder = newValue }
    }

    /// 渲染类型
    var drawType: String {
        get { return _storage._drawType }
        set { _uniqueStorage()._drawType = newValue }
    }

    /// 青少年模式
    var seniorModeSwitch: Int32 {
        get { return _storage._seniorModeSwitch }
        set { _uniqueStorage()._seniorModeSwitch = newValue }
    }

    var aiLevelV2: Int32 {
        get { return _storage._aiLevelV2 }
        set { _uniqueStorage()._aiLevelV2 = newValue }
    }

    var aiLevelV2Map: [Int32: Int32] {
        get { return _storage._aiLevelV2Map }
        set { _uniqueStorage()._aiLevelV2Map = newValue }
    }

    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}

    fileprivate var _storage = _StorageClass.defaultInstance
}

struct Expressions {
    // SwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
    // methods supported on all messages.

    var data: [Expressions.Expression] = []

    var unknownFields = SwiftProtobuf.UnknownStorage()

    struct Expression {
        // SwiftProtobuf.Message conformance is added in an extension below. See the
        // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
        // methods supported on all messages.

        var keyword: [String] = []

        var url: String = .init()

        var period: [Expressions.Expression.Period] = []

        var unknownFields = SwiftProtobuf.UnknownStorage()

        struct Period {
            // SwiftProtobuf.Message conformance is added in an extension below. See the
            // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
            // methods supported on all messages.

            var start: Int64 = 0

            var end: Int64 = 0

            var unknownFields = SwiftProtobuf.UnknownStorage()

            init() {}
        }

        init() {}
    }

    init() {}
}

struct DmWebViewReply {
    // SwiftProtobuf.Message conformance is added in an extension below. See the
    // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
    // methods supported on all messages.

    /// 弹幕开放状态 0:未关闭 1:已关闭
    var state: Int32 = 0

    var text: String = .init()

    var textSide: String = .init()

    /// 分段弹幕包信息？
    var dmSge: DmSegConfig {
        get { return _dmSge ?? DmSegConfig() }
        set { _dmSge = newValue }
    }

    /// Returns true if `dmSge` has been explicitly set.
    var hasDmSge: Bool { return self._dmSge != nil }
    /// Clears the value of `dmSge`. Subsequent reads from it will return its default value.
    mutating func clearDmSge() { _dmSge = nil }

    /// 云屏蔽配置信息
    var flag: DanmakuFlagConfig {
        get { return _flag ?? DanmakuFlagConfig() }
        set { _flag = newValue }
    }

    /// Returns true if `flag` has been explicitly set.
    var hasFlag: Bool { return self._flag != nil }
    /// Clears the value of `flag`. Subsequent reads from it will return its default value.
    mutating func clearFlag() { _flag = nil }

    /// BAS（代码）弹幕专包url
    var specialDms: [String] = []

    /// check box 是否展示
    var checkBox: Bool = false

    /// 实际弹幕总数
    var count: Int64 = 0

    /// 互动弹幕条目
    var commandDms: [CommandDm] = []

    /// 弹幕个人配置
    var playerConfig: DanmuWebPlayerConfig {
        get { return _playerConfig ?? DanmuWebPlayerConfig() }
        set { _playerConfig = newValue }
    }

    /// Returns true if `playerConfig` has been explicitly set.
    var hasPlayerConfig: Bool { return self._playerConfig != nil }
    /// Clears the value of `playerConfig`. Subsequent reads from it will return its default value.
    mutating func clearPlayerConfig() { _playerConfig = nil }

    /// 用户举报弹幕 cid维度屏蔽
    var reportFilterContent: [String] = []

    var expressions: [Expressions] = []

    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}

    fileprivate var _dmSge: DmSegConfig?
    fileprivate var _flag: DanmakuFlagConfig?
    fileprivate var _playerConfig: DanmuWebPlayerConfig?
}

#if swift(>=5.5) && canImport(_Concurrency)
    extension DmSegConfig: @unchecked Sendable {}
    extension DanmakuFlagConfig: @unchecked Sendable {}
    extension CommandDm: @unchecked Sendable {}
    extension DanmuWebPlayerConfig: @unchecked Sendable {}
    extension Expressions: @unchecked Sendable {}
    extension Expressions.Expression: @unchecked Sendable {}
    extension Expressions.Expression.Period: @unchecked Sendable {}
    extension DmWebViewReply: @unchecked Sendable {}
#endif // swift(>=5.5) && canImport(_Concurrency)

// MARK: - Code below here is support for the SwiftProtobuf runtime.

extension DmSegConfig: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName: String = "DmSegConfig"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "pageSize"),
        2: .same(proto: "total"),
    ]

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            // The use of inline closures is to circumvent an issue where the compiler
            // allocates stack space for every case branch when no optimizations are
            // enabled. https://github.com/apple/swift-protobuf/issues/1034
            switch fieldNumber {
            case 1: try try decoder.decodeSingularInt64Field(value: &pageSize)
            case 2: try try decoder.decodeSingularInt64Field(value: &total)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if pageSize != 0 {
            try visitor.visitSingularInt64Field(value: pageSize, fieldNumber: 1)
        }
        if total != 0 {
            try visitor.visitSingularInt64Field(value: total, fieldNumber: 2)
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: DmSegConfig, rhs: DmSegConfig) -> Bool {
        if lhs.pageSize != rhs.pageSize { return false }
        if lhs.total != rhs.total { return false }
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}

extension DanmakuFlagConfig: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName: String = "DanmakuFlagConfig"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "recFlag"),
        2: .same(proto: "recText"),
        3: .same(proto: "recSwitch"),
    ]

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            // The use of inline closures is to circumvent an issue where the compiler
            // allocates stack space for every case branch when no optimizations are
            // enabled. https://github.com/apple/swift-protobuf/issues/1034
            switch fieldNumber {
            case 1: try try decoder.decodeSingularInt32Field(value: &recFlag)
            case 2: try try decoder.decodeSingularStringField(value: &recText)
            case 3: try try decoder.decodeSingularInt32Field(value: &recSwitch)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if recFlag != 0 {
            try visitor.visitSingularInt32Field(value: recFlag, fieldNumber: 1)
        }
        if !recText.isEmpty {
            try visitor.visitSingularStringField(value: recText, fieldNumber: 2)
        }
        if recSwitch != 0 {
            try visitor.visitSingularInt32Field(value: recSwitch, fieldNumber: 3)
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: DanmakuFlagConfig, rhs: DanmakuFlagConfig) -> Bool {
        if lhs.recFlag != rhs.recFlag { return false }
        if lhs.recText != rhs.recText { return false }
        if lhs.recSwitch != rhs.recSwitch { return false }
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}

extension CommandDm: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName: String = "CommandDm"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "id"),
        2: .same(proto: "oid"),
        3: .same(proto: "mid"),
        4: .same(proto: "command"),
        5: .same(proto: "content"),
        6: .same(proto: "progress"),
        7: .same(proto: "ctime"),
        8: .same(proto: "mtime"),
        9: .same(proto: "extra"),
        10: .same(proto: "idStr"),
    ]

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            // The use of inline closures is to circumvent an issue where the compiler
            // allocates stack space for every case branch when no optimizations are
            // enabled. https://github.com/apple/swift-protobuf/issues/1034
            switch fieldNumber {
            case 1: try try decoder.decodeSingularInt64Field(value: &id)
            case 2: try try decoder.decodeSingularInt64Field(value: &oid)
            case 3: try try decoder.decodeSingularInt64Field(value: &mid)
            case 4: try try decoder.decodeSingularStringField(value: &command)
            case 5: try try decoder.decodeSingularStringField(value: &content)
            case 6: try try decoder.decodeSingularInt32Field(value: &progress)
            case 7: try try decoder.decodeSingularStringField(value: &ctime)
            case 8: try try decoder.decodeSingularStringField(value: &mtime)
            case 9: try try decoder.decodeSingularStringField(value: &extra)
            case 10: try try decoder.decodeSingularStringField(value: &idStr)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if id != 0 {
            try visitor.visitSingularInt64Field(value: id, fieldNumber: 1)
        }
        if oid != 0 {
            try visitor.visitSingularInt64Field(value: oid, fieldNumber: 2)
        }
        if mid != 0 {
            try visitor.visitSingularInt64Field(value: mid, fieldNumber: 3)
        }
        if !command.isEmpty {
            try visitor.visitSingularStringField(value: command, fieldNumber: 4)
        }
        if !content.isEmpty {
            try visitor.visitSingularStringField(value: content, fieldNumber: 5)
        }
        if progress != 0 {
            try visitor.visitSingularInt32Field(value: progress, fieldNumber: 6)
        }
        if !ctime.isEmpty {
            try visitor.visitSingularStringField(value: ctime, fieldNumber: 7)
        }
        if !mtime.isEmpty {
            try visitor.visitSingularStringField(value: mtime, fieldNumber: 8)
        }
        if !extra.isEmpty {
            try visitor.visitSingularStringField(value: extra, fieldNumber: 9)
        }
        if !idStr.isEmpty {
            try visitor.visitSingularStringField(value: idStr, fieldNumber: 10)
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: CommandDm, rhs: CommandDm) -> Bool {
        if lhs.id != rhs.id { return false }
        if lhs.oid != rhs.oid { return false }
        if lhs.mid != rhs.mid { return false }
        if lhs.command != rhs.command { return false }
        if lhs.content != rhs.content { return false }
        if lhs.progress != rhs.progress { return false }
        if lhs.ctime != rhs.ctime { return false }
        if lhs.mtime != rhs.mtime { return false }
        if lhs.extra != rhs.extra { return false }
        if lhs.idStr != rhs.idStr { return false }
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}

extension DanmuWebPlayerConfig: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName: String = "DanmuWebPlayerConfig"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "dmSwitch"),
        2: .same(proto: "aiSwitch"),
        3: .same(proto: "aiLevel"),
        4: .same(proto: "blocktop"),
        5: .same(proto: "blockscroll"),
        6: .same(proto: "blockbottom"),
        7: .same(proto: "blockcolor"),
        8: .same(proto: "blockspecial"),
        9: .same(proto: "preventshade"),
        10: .same(proto: "dmask"),
        11: .same(proto: "opacity"),
        12: .same(proto: "dmarea"),
        13: .same(proto: "speedplus"),
        14: .same(proto: "fontsize"),
        15: .same(proto: "screensync"),
        16: .same(proto: "speedsync"),
        17: .same(proto: "fontfamily"),
        18: .same(proto: "bold"),
        19: .same(proto: "fontborder"),
        20: .same(proto: "drawType"),
        21: .same(proto: "seniorModeSwitch"),
        22: .same(proto: "aiLevelV2"),
        23: .same(proto: "aiLevelV2Map"),
    ]

    fileprivate class _StorageClass {
        var _dmSwitch: Bool = false
        var _aiSwitch: Bool = false
        var _aiLevel: Int32 = 0
        var _blocktop: Bool = false
        var _blockscroll: Bool = false
        var _blockbottom: Bool = false
        var _blockcolor: Bool = false
        var _blockspecial: Bool = false
        var _preventshade: Bool = false
        var _dmask: Bool = false
        var _opacity: Float = 0
        var _dmarea: Int32 = 0
        var _speedplus: Float = 0
        var _fontsize: Float = 0
        var _screensync: Bool = false
        var _speedsync: Bool = false
        var _fontfamily: String = .init()
        var _bold: Bool = false
        var _fontborder: Int32 = 0
        var _drawType: String = .init()
        var _seniorModeSwitch: Int32 = 0
        var _aiLevelV2: Int32 = 0
        var _aiLevelV2Map: [Int32: Int32] = [:]

        static let defaultInstance = _StorageClass()

        private init() {}

        init(copying source: _StorageClass) {
            _dmSwitch = source._dmSwitch
            _aiSwitch = source._aiSwitch
            _aiLevel = source._aiLevel
            _blocktop = source._blocktop
            _blockscroll = source._blockscroll
            _blockbottom = source._blockbottom
            _blockcolor = source._blockcolor
            _blockspecial = source._blockspecial
            _preventshade = source._preventshade
            _dmask = source._dmask
            _opacity = source._opacity
            _dmarea = source._dmarea
            _speedplus = source._speedplus
            _fontsize = source._fontsize
            _screensync = source._screensync
            _speedsync = source._speedsync
            _fontfamily = source._fontfamily
            _bold = source._bold
            _fontborder = source._fontborder
            _drawType = source._drawType
            _seniorModeSwitch = source._seniorModeSwitch
            _aiLevelV2 = source._aiLevelV2
            _aiLevelV2Map = source._aiLevelV2Map
        }
    }

    fileprivate mutating func _uniqueStorage() -> _StorageClass {
        if !isKnownUniquelyReferenced(&_storage) {
            _storage = _StorageClass(copying: _storage)
        }
        return _storage
    }

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        _ = _uniqueStorage()
        try withExtendedLifetime(_storage) { (_storage: _StorageClass) in
            while let fieldNumber = try decoder.nextFieldNumber() {
                // The use of inline closures is to circumvent an issue where the compiler
                // allocates stack space for every case branch when no optimizations are
                // enabled. https://github.com/apple/swift-protobuf/issues/1034
                switch fieldNumber {
                case 1: try try decoder.decodeSingularBoolField(value: &_storage._dmSwitch)
                case 2: try try decoder.decodeSingularBoolField(value: &_storage._aiSwitch)
                case 3: try try decoder.decodeSingularInt32Field(value: &_storage._aiLevel)
                case 4: try try decoder.decodeSingularBoolField(value: &_storage._blocktop)
                case 5: try try decoder.decodeSingularBoolField(value: &_storage._blockscroll)
                case 6: try try decoder.decodeSingularBoolField(value: &_storage._blockbottom)
                case 7: try try decoder.decodeSingularBoolField(value: &_storage._blockcolor)
                case 8: try try decoder.decodeSingularBoolField(value: &_storage._blockspecial)
                case 9: try try decoder.decodeSingularBoolField(value: &_storage._preventshade)
                case 10: try try decoder.decodeSingularBoolField(value: &_storage._dmask)
                case 11: try try decoder.decodeSingularFloatField(value: &_storage._opacity)
                case 12: try try decoder.decodeSingularInt32Field(value: &_storage._dmarea)
                case 13: try try decoder.decodeSingularFloatField(value: &_storage._speedplus)
                case 14: try try decoder.decodeSingularFloatField(value: &_storage._fontsize)
                case 15: try try decoder.decodeSingularBoolField(value: &_storage._screensync)
                case 16: try try decoder.decodeSingularBoolField(value: &_storage._speedsync)
                case 17: try try decoder.decodeSingularStringField(value: &_storage._fontfamily)
                case 18: try try decoder.decodeSingularBoolField(value: &_storage._bold)
                case 19: try try decoder.decodeSingularInt32Field(value: &_storage._fontborder)
                case 20: try try decoder.decodeSingularStringField(value: &_storage._drawType)
                case 21: try try decoder.decodeSingularInt32Field(value: &_storage._seniorModeSwitch)
                case 22: try try decoder.decodeSingularInt32Field(value: &_storage._aiLevelV2)
                case 23: try { try decoder.decodeMapField(fieldType: SwiftProtobuf._ProtobufMap<SwiftProtobuf.ProtobufInt32, SwiftProtobuf.ProtobufInt32>.self, value: &_storage._aiLevelV2Map) }()
                default: break
                }
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        try withExtendedLifetime(_storage) { (_storage: _StorageClass) in
            if _storage._dmSwitch != false {
                try visitor.visitSingularBoolField(value: _storage._dmSwitch, fieldNumber: 1)
            }
            if _storage._aiSwitch != false {
                try visitor.visitSingularBoolField(value: _storage._aiSwitch, fieldNumber: 2)
            }
            if _storage._aiLevel != 0 {
                try visitor.visitSingularInt32Field(value: _storage._aiLevel, fieldNumber: 3)
            }
            if _storage._blocktop != false {
                try visitor.visitSingularBoolField(value: _storage._blocktop, fieldNumber: 4)
            }
            if _storage._blockscroll != false {
                try visitor.visitSingularBoolField(value: _storage._blockscroll, fieldNumber: 5)
            }
            if _storage._blockbottom != false {
                try visitor.visitSingularBoolField(value: _storage._blockbottom, fieldNumber: 6)
            }
            if _storage._blockcolor != false {
                try visitor.visitSingularBoolField(value: _storage._blockcolor, fieldNumber: 7)
            }
            if _storage._blockspecial != false {
                try visitor.visitSingularBoolField(value: _storage._blockspecial, fieldNumber: 8)
            }
            if _storage._preventshade != false {
                try visitor.visitSingularBoolField(value: _storage._preventshade, fieldNumber: 9)
            }
            if _storage._dmask != false {
                try visitor.visitSingularBoolField(value: _storage._dmask, fieldNumber: 10)
            }
            if _storage._opacity != 0 {
                try visitor.visitSingularFloatField(value: _storage._opacity, fieldNumber: 11)
            }
            if _storage._dmarea != 0 {
                try visitor.visitSingularInt32Field(value: _storage._dmarea, fieldNumber: 12)
            }
            if _storage._speedplus != 0 {
                try visitor.visitSingularFloatField(value: _storage._speedplus, fieldNumber: 13)
            }
            if _storage._fontsize != 0 {
                try visitor.visitSingularFloatField(value: _storage._fontsize, fieldNumber: 14)
            }
            if _storage._screensync != false {
                try visitor.visitSingularBoolField(value: _storage._screensync, fieldNumber: 15)
            }
            if _storage._speedsync != false {
                try visitor.visitSingularBoolField(value: _storage._speedsync, fieldNumber: 16)
            }
            if !_storage._fontfamily.isEmpty {
                try visitor.visitSingularStringField(value: _storage._fontfamily, fieldNumber: 17)
            }
            if _storage._bold != false {
                try visitor.visitSingularBoolField(value: _storage._bold, fieldNumber: 18)
            }
            if _storage._fontborder != 0 {
                try visitor.visitSingularInt32Field(value: _storage._fontborder, fieldNumber: 19)
            }
            if !_storage._drawType.isEmpty {
                try visitor.visitSingularStringField(value: _storage._drawType, fieldNumber: 20)
            }
            if _storage._seniorModeSwitch != 0 {
                try visitor.visitSingularInt32Field(value: _storage._seniorModeSwitch, fieldNumber: 21)
            }
            if _storage._aiLevelV2 != 0 {
                try visitor.visitSingularInt32Field(value: _storage._aiLevelV2, fieldNumber: 22)
            }
            if !_storage._aiLevelV2Map.isEmpty {
                try visitor.visitMapField(fieldType: SwiftProtobuf._ProtobufMap<SwiftProtobuf.ProtobufInt32, SwiftProtobuf.ProtobufInt32>.self, value: _storage._aiLevelV2Map, fieldNumber: 23)
            }
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: DanmuWebPlayerConfig, rhs: DanmuWebPlayerConfig) -> Bool {
        if lhs._storage !== rhs._storage {
            let storagesAreEqual: Bool = withExtendedLifetime((lhs._storage, rhs._storage)) { (_args: (_StorageClass, _StorageClass)) in
                let _storage = _args.0
                let rhs_storage = _args.1
                if _storage._dmSwitch != rhs_storage._dmSwitch { return false }
                if _storage._aiSwitch != rhs_storage._aiSwitch { return false }
                if _storage._aiLevel != rhs_storage._aiLevel { return false }
                if _storage._blocktop != rhs_storage._blocktop { return false }
                if _storage._blockscroll != rhs_storage._blockscroll { return false }
                if _storage._blockbottom != rhs_storage._blockbottom { return false }
                if _storage._blockcolor != rhs_storage._blockcolor { return false }
                if _storage._blockspecial != rhs_storage._blockspecial { return false }
                if _storage._preventshade != rhs_storage._preventshade { return false }
                if _storage._dmask != rhs_storage._dmask { return false }
                if _storage._opacity != rhs_storage._opacity { return false }
                if _storage._dmarea != rhs_storage._dmarea { return false }
                if _storage._speedplus != rhs_storage._speedplus { return false }
                if _storage._fontsize != rhs_storage._fontsize { return false }
                if _storage._screensync != rhs_storage._screensync { return false }
                if _storage._speedsync != rhs_storage._speedsync { return false }
                if _storage._fontfamily != rhs_storage._fontfamily { return false }
                if _storage._bold != rhs_storage._bold { return false }
                if _storage._fontborder != rhs_storage._fontborder { return false }
                if _storage._drawType != rhs_storage._drawType { return false }
                if _storage._seniorModeSwitch != rhs_storage._seniorModeSwitch { return false }
                if _storage._aiLevelV2 != rhs_storage._aiLevelV2 { return false }
                if _storage._aiLevelV2Map != rhs_storage._aiLevelV2Map { return false }
                return true
            }
            if !storagesAreEqual { return false }
        }
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}

extension Expressions: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName: String = "Expressions"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "data"),
    ]

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            // The use of inline closures is to circumvent an issue where the compiler
            // allocates stack space for every case branch when no optimizations are
            // enabled. https://github.com/apple/swift-protobuf/issues/1034
            switch fieldNumber {
            case 1: try try decoder.decodeRepeatedMessageField(value: &data)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !data.isEmpty {
            try visitor.visitRepeatedMessageField(value: data, fieldNumber: 1)
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: Expressions, rhs: Expressions) -> Bool {
        if lhs.data != rhs.data { return false }
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}

extension Expressions.Expression: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName: String = Expressions.protoMessageName + ".Expression"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "keyword"),
        2: .same(proto: "url"),
        3: .same(proto: "period"),
    ]

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            // The use of inline closures is to circumvent an issue where the compiler
            // allocates stack space for every case branch when no optimizations are
            // enabled. https://github.com/apple/swift-protobuf/issues/1034
            switch fieldNumber {
            case 1: try try decoder.decodeRepeatedStringField(value: &keyword)
            case 2: try try decoder.decodeSingularStringField(value: &url)
            case 3: try try decoder.decodeRepeatedMessageField(value: &period)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !keyword.isEmpty {
            try visitor.visitRepeatedStringField(value: keyword, fieldNumber: 1)
        }
        if !url.isEmpty {
            try visitor.visitSingularStringField(value: url, fieldNumber: 2)
        }
        if !period.isEmpty {
            try visitor.visitRepeatedMessageField(value: period, fieldNumber: 3)
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: Expressions.Expression, rhs: Expressions.Expression) -> Bool {
        if lhs.keyword != rhs.keyword { return false }
        if lhs.url != rhs.url { return false }
        if lhs.period != rhs.period { return false }
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}

extension Expressions.Expression.Period: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName: String = Expressions.Expression.protoMessageName + ".Period"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "start"),
        2: .same(proto: "end"),
    ]

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            // The use of inline closures is to circumvent an issue where the compiler
            // allocates stack space for every case branch when no optimizations are
            // enabled. https://github.com/apple/swift-protobuf/issues/1034
            switch fieldNumber {
            case 1: try try decoder.decodeSingularInt64Field(value: &start)
            case 2: try try decoder.decodeSingularInt64Field(value: &end)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if start != 0 {
            try visitor.visitSingularInt64Field(value: start, fieldNumber: 1)
        }
        if end != 0 {
            try visitor.visitSingularInt64Field(value: end, fieldNumber: 2)
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: Expressions.Expression.Period, rhs: Expressions.Expression.Period) -> Bool {
        if lhs.start != rhs.start { return false }
        if lhs.end != rhs.end { return false }
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}

extension DmWebViewReply: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName: String = "DmWebViewReply"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "state"),
        2: .same(proto: "text"),
        3: .same(proto: "textSide"),
        4: .same(proto: "dmSge"),
        5: .same(proto: "flag"),
        6: .same(proto: "specialDms"),
        7: .same(proto: "checkBox"),
        8: .same(proto: "count"),
        9: .same(proto: "commandDms"),
        10: .same(proto: "playerConfig"),
        11: .same(proto: "reportFilterContent"),
        12: .same(proto: "expressions"),
    ]

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            // The use of inline closures is to circumvent an issue where the compiler
            // allocates stack space for every case branch when no optimizations are
            // enabled. https://github.com/apple/swift-protobuf/issues/1034
            switch fieldNumber {
            case 1: try try decoder.decodeSingularInt32Field(value: &state)
            case 2: try try decoder.decodeSingularStringField(value: &text)
            case 3: try try decoder.decodeSingularStringField(value: &textSide)
            case 4: try try decoder.decodeSingularMessageField(value: &_dmSge)
            case 5: try try decoder.decodeSingularMessageField(value: &_flag)
            case 6: try try decoder.decodeRepeatedStringField(value: &specialDms)
            case 7: try try decoder.decodeSingularBoolField(value: &checkBox)
            case 8: try try decoder.decodeSingularInt64Field(value: &count)
            case 9: try try decoder.decodeRepeatedMessageField(value: &commandDms)
            case 10: try try decoder.decodeSingularMessageField(value: &_playerConfig)
            case 11: try try decoder.decodeRepeatedStringField(value: &reportFilterContent)
            case 12: try try decoder.decodeRepeatedMessageField(value: &expressions)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        // The use of inline closures is to circumvent an issue where the compiler
        // allocates stack space for every if/case branch local when no optimizations
        // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
        // https://github.com/apple/swift-protobuf/issues/1182
        if state != 0 {
            try visitor.visitSingularInt32Field(value: state, fieldNumber: 1)
        }
        if !text.isEmpty {
            try visitor.visitSingularStringField(value: text, fieldNumber: 2)
        }
        if !textSide.isEmpty {
            try visitor.visitSingularStringField(value: textSide, fieldNumber: 3)
        }
        try { if let v = self._dmSge {
            try visitor.visitSingularMessageField(value: v, fieldNumber: 4)
        } }()
        try { if let v = self._flag {
            try visitor.visitSingularMessageField(value: v, fieldNumber: 5)
        } }()
        if !specialDms.isEmpty {
            try visitor.visitRepeatedStringField(value: specialDms, fieldNumber: 6)
        }
        if checkBox != false {
            try visitor.visitSingularBoolField(value: checkBox, fieldNumber: 7)
        }
        if count != 0 {
            try visitor.visitSingularInt64Field(value: count, fieldNumber: 8)
        }
        if !commandDms.isEmpty {
            try visitor.visitRepeatedMessageField(value: commandDms, fieldNumber: 9)
        }
        try { if let v = self._playerConfig {
            try visitor.visitSingularMessageField(value: v, fieldNumber: 10)
        } }()
        if !reportFilterContent.isEmpty {
            try visitor.visitRepeatedStringField(value: reportFilterContent, fieldNumber: 11)
        }
        if !expressions.isEmpty {
            try visitor.visitRepeatedMessageField(value: expressions, fieldNumber: 12)
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: DmWebViewReply, rhs: DmWebViewReply) -> Bool {
        if lhs.state != rhs.state { return false }
        if lhs.text != rhs.text { return false }
        if lhs.textSide != rhs.textSide { return false }
        if lhs._dmSge != rhs._dmSge { return false }
        if lhs._flag != rhs._flag { return false }
        if lhs.specialDms != rhs.specialDms { return false }
        if lhs.checkBox != rhs.checkBox { return false }
        if lhs.count != rhs.count { return false }
        if lhs.commandDms != rhs.commandDms { return false }
        if lhs._playerConfig != rhs._playerConfig { return false }
        if lhs.reportFilterContent != rhs.reportFilterContent { return false }
        if lhs.expressions != rhs.expressions { return false }
        if lhs.unknownFields != rhs.unknownFields { return false }
        return true
    }
}
