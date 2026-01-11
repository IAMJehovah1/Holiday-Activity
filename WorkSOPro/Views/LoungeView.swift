//
//  LoungeView.swift
//  WorkSOPro
//
//  Main view for employee lounge - communication and winddown space
//

import SwiftUI

struct LoungeView: View {
    @StateObject private var loungeManager = LoungeManager()
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var wellBeingManager: WellBeingManager
    @State private var selectedLounge: Lounge?
    @State private var showCreateLounge = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(loungeManager.lounges) { lounge in
                        LoungeRowView(lounge: lounge, unreadCount: loungeManager.unreadCounts[lounge.id] ?? 0)
                            .onTapGesture {
                                selectedLounge = lounge
                                loungeManager.markAsRead(loungeId: lounge.id)
                            }
                    }
                } header: {
                    Text("Available Lounges")
                }
                
                Section {
                    NavigationLink(destination: WinddownActivitiesView(loungeManager: loungeManager)) {
                        HStack {
                            Image(systemName: "moon.stars.fill")
                                .foregroundColor(.purple)
                            Text("Winddown Activities")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    NavigationLink(destination: WellnessResourcesView()) {
                        HStack {
                            Image(systemName: "heart.circle.fill")
                                .foregroundColor(.pink)
                            Text("Wellness Resources")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("Wellbeing")
                }
            }
            .navigationTitle("Lounge")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateLounge = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(item: $selectedLounge) { lounge in
                LoungeDetailView(lounge: lounge, loungeManager: loungeManager)
            }
            .sheet(isPresented: $showCreateLounge) {
                CreateLoungeView(loungeManager: loungeManager)
            }
        }
    }
}

struct LoungeRowView: View {
    let lounge: Lounge
    let unreadCount: Int
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(lounge.loungeColor.color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: lounge.type.icon)
                    .foregroundColor(lounge.loungeColor.color)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(lounge.name)
                        .font(.headline)
                    
                    if unreadCount > 0 {
                        Text("\(unreadCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
                
                Text(lounge.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text("\(lounge.members.count) members")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct LoungeDetailView: View {
    let lounge: Lounge
    @ObservedObject var loungeManager: LoungeManager
    @EnvironmentObject var appState: AppState
    @State private var messageText = ""
    @State private var showActivities = false
    @State private var scrollProxy: ScrollViewProxy?
    
    var messages: [LoungeMessage] {
        loungeManager.getMessages(for: lounge.id).sorted { $0.timestamp < $1.timestamp }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(lounge.name)
                        .font(.title2)
                        .bold()
                    Text(lounge.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    showActivities = true
                } label: {
                    Image(systemName: "star.circle.fill")
                        .font(.title2)
                        .foregroundColor(lounge.loungeColor.color)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if messages.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: lounge.type.icon)
                                    .font(.system(size: 60))
                                    .foregroundColor(lounge.loungeColor.color.opacity(0.3))
                                
                                Text("No messages yet")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text("Be the first to start the conversation!")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                        } else {
                            ForEach(messages) { message in
                                MessageBubbleView(message: message, loungeManager: loungeManager)
                                    .id(message.id)
                            }
                        }
                    }
                    .padding()
                }
                .onAppear {
                    scrollProxy = proxy
                    if let lastMessage = messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            
            Divider()
            
            // Message Input
            HStack(spacing: 12) {
                TextField("Type a message...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(messageText.isEmpty ? .secondary : lounge.loungeColor.color)
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .sheet(isPresented: $showActivities) {
            LoungeActivitiesView(lounge: lounge, loungeManager: loungeManager)
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty,
              let userId = appState.currentUser?.id.uuidString,
              let userName = appState.currentUser?.name else {
            return
        }
        
        let message = LoungeMessage(
            loungeId: lounge.id,
            authorId: userId,
            authorName: userName,
            content: messageText
        )
        
        loungeManager.sendMessage(message)
        messageText = ""
        
        // Scroll to new message
        if let proxy = scrollProxy {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                proxy.scrollTo(message.id, anchor: .bottom)
            }
        }
    }
}

struct MessageBubbleView: View {
    let message: LoungeMessage
    @ObservedObject var loungeManager: LoungeManager
    @EnvironmentObject var appState: AppState
    @State private var showReactions = false
    
    var isOwnMessage: Bool {
        message.authorId == appState.currentUser?.id.uuidString
    }
    
    var body: some View {
        VStack(alignment: isOwnMessage ? .trailing : .leading, spacing: 4) {
            HStack {
                if isOwnMessage {
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // Message header
                    HStack {
                        Text(message.authorName)
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Text(message.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Message content
                    Text(message.content)
                        .font(.body)
                    
                    // Message type indicator
                    if message.messageType != .text {
                        Label(message.messageType.rawValue, systemImage: messageTypeIcon(message.messageType))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Reactions
                    if !message.reactions.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(message.reactions) { reaction in
                                HStack(spacing: 2) {
                                    Text(reaction.emoji)
                                    Text("\(reaction.userIds.count)")
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                .padding(12)
                .background(isOwnMessage ? Color.blue.opacity(0.1) : Color(.systemGray6))
                .cornerRadius(16)
                .contextMenu {
                    Button {
                        addReaction("👍")
                    } label: {
                        Label("👍 Like", systemImage: "hand.thumbsup")
                    }
                    
                    Button {
                        addReaction("❤️")
                    } label: {
                        Label("❤️ Love", systemImage: "heart")
                    }
                    
                    Button {
                        addReaction("😊")
                    } label: {
                        Label("😊 Smile", systemImage: "face.smiling")
                    }
                    
                    Button {
                        addReaction("🎉")
                    } label: {
                        Label("🎉 Celebrate", systemImage: "party.popper")
                    }
                }
                
                if !isOwnMessage {
                    Spacer()
                }
            }
        }
    }
    
    private func messageTypeIcon(_ type: LoungeMessage.MessageType) -> String {
        switch type {
        case .text: return "text.bubble"
        case .poll: return "chart.bar.doc.horizontal"
        case .announcement: return "megaphone"
        case .winddownActivity: return "moon.stars"
        case .celebration: return "party.popper"
        case .gratitude: return "heart"
        case .meditation: return "sparkles"
        }
    }
    
    private func addReaction(_ emoji: String) {
        guard let userId = appState.currentUser?.id.uuidString else { return }
        loungeManager.addReaction(to: message, emoji: emoji, userId: userId)
    }
}

struct LoungeActivitiesView: View {
    let lounge: Lounge
    @ObservedObject var loungeManager: LoungeManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Suggested Activities") {
                    ForEach(lounge.type.suggestedActivities, id: \.self) { activity in
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text(activity)
                        }
                    }
                }
                
                if lounge.type == .winddown {
                    Section("Quick Winddown") {
                        ForEach(loungeManager.winddownActivities.prefix(3)) { activity in
                            NavigationLink(destination: WinddownActivityDetailView(activity: activity, loungeManager: loungeManager)) {
                                HStack {
                                    Image(systemName: activity.type.icon)
                                        .foregroundColor(activity.type.color)
                                    VStack(alignment: .leading) {
                                        Text(activity.title)
                                            .font(.headline)
                                        Text("\(activity.durationMinutes) min")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Activities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    LoungeView()
        .environmentObject(AppState())
        .environmentObject(WellBeingManager())
}
