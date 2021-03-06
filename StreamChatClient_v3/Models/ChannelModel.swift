//
// Copyright © 2020 Stream.io Inc. All rights reserved.
//

import Foundation

public struct ChannelModel<ExtraData: ExtraDataTypes> {
    /// A channel type + id.
    public let cid: ChannelId
    
    /// The date of the last message in the channel.
    public let lastMessageDate: Date?
    
    /// The date when the channel was created.
    public let created: Date
    
    /// The date when the channel was updated.
    public let updated: Date
    
    /// If the channel weas deleted, this field contains the date of the deletion.
    public let deleted: Date?
    
    /// The user which created the channel.
    public let createdBy: UserModel<ExtraData.User>?
    
    /// A config.
    public let config: ChannelConfig
    
    /// Checks if the channel is frozen.
    public let frozen: Bool
    
    /// A list of channel members.
    public let members: Set<MemberModel<ExtraData.User>>
    
    /// A list of channel watchers.
    public let watchers: Set<UserModel<ExtraData.User>>
    
    /// The team the channel belongs to. You need to enable multi-tenancy if you want to use this, else it'll be nil.
    /// Refer to [docs](https://getstream.io/chat/docs/multi_tenant_chat/?language=swift) for more info.
    public let team: String
    
    /// Returns the current unread count.
    public let unreadCount: ChannelUnreadCount
    
    /// Online watchers in the channel.
    public let watcherCount: Int
    
    /// Unread message state for the current user.
    public let unreadMessageRead: MessageRead<ExtraData.User>?
    
    /// An option to enable ban users.
    public let banEnabling: BanEnabling
    
    /// Checks if the channel is watching by the client.
    public let isWatched: Bool
    
    // TODO: refactor comment and add latestMessages limit mention
    /// Latest messages present on the channel.
    public let latestMessages: [MessageModel<ExtraData>]
    
    public let extraData: ExtraData.Channel
    
    // MARK: - Internal
    
    /// A helper variable to cache the result of the filter for only banned members.
    //  lazy var bannedMembers: Set<MemberModel<ExtraData.User>> = Set(self.members.filter { $0.isBanned })
    
    /// A list of users to invite in the channel.
    let invitedMembers: Set<MemberModel<ExtraData.User>> // TODO: Why is this not public?
    
    init(cid: ChannelId,
        lastMessageDate: Date? = nil,
        created: Date = .init(),
        updated: Date = .init(),
        deleted: Date? = nil,
        createdBy: UserModel<ExtraData.User>? = nil,
        config: ChannelConfig = .init(),
        frozen: Bool = false,
        members: Set<MemberModel<ExtraData.User>> = [],
        watchers: Set<UserModel<ExtraData.User>> = [],
        team: String = "",
        unreadCount: ChannelUnreadCount = .noUnread,
        watcherCount: Int = 0,
        unreadMessageRead: MessageRead<ExtraData.User>? = nil,
        banEnabling: BanEnabling = .disabled,
        isWatched: Bool = false,
        extraData: ExtraData.Channel,
        invitedMembers: Set<MemberModel<ExtraData.User>> = [],
        latestMessages: [MessageModel<ExtraData>] = []) {
        self.cid = cid
        self.lastMessageDate = lastMessageDate
        self.created = created
        self.updated = updated
        self.deleted = deleted
        self.createdBy = createdBy
        self.config = config
        self.frozen = frozen
        self.members = members
        self.watchers = watchers
        self.team = team
        self.unreadCount = unreadCount
        self.watcherCount = watcherCount
        self.unreadMessageRead = unreadMessageRead
        self.banEnabling = banEnabling
        self.isWatched = isWatched
        self.extraData = extraData
        self.invitedMembers = invitedMembers
        self.latestMessages = latestMessages
    }
}

extension ChannelModel {
    /// A channel type.
    public var type: ChannelType { cid.type }
    
    /// Check if the channel was deleted.
    public var isDeleted: Bool { deleted != nil }
    
    /// Checks if read events evalable for the current user.
    public var readEventsEnabled: Bool { /* config.readEventsEnabled && members.contains(Member.current) */ fatalError() }
    
    /// Checks if the channel is direct message type between 2 users.
    public var isDirectMessage: Bool { cid.id.hasPrefix("!members") && members.count == 2 }
    
    /// Checks if the current status of the channel is unread.
    public var isUnread: Bool { unreadCount.messages > 0 }
    
    /// Checks for the channel data encoding is empty.
    var isEmpty: Bool { /* extraData == nil && members.isEmpty && invitedMembers.isEmpty */ fatalError() }
}

/// A convenience `ChannelModel` typealias with no additional channel data.
public typealias Channel = ChannelModel<DefaultDataTypes>

public protocol ChannelExtraData: Codable & Hashable {}

/// A type-erased version of `ChannelModel<CustomData>`. Not intended to be used directly.
public protocol AnyChannel {}
extension ChannelModel: AnyChannel {}

extension ChannelModel: Equatable {
    public static func == (lhs: ChannelModel<ExtraData>, rhs: ChannelModel<ExtraData>) -> Bool {
        lhs.cid == rhs.cid
    }
}

/// An unread counts for a channel.
public struct ChannelUnreadCount: Decodable, Equatable {
    public static let noUnread = ChannelUnreadCount(messages: 0, mentionedMessages: 0)
    public internal(set) var messages: Int
    public internal(set) var mentionedMessages: Int
}
