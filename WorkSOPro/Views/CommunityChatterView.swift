//
//  CommunityChatterView.swift
//  WorkSOPro
//
//  View for Community Chatter physical lounge space and CxT Coffee Shop
//

import SwiftUI

struct CommunityChatterView: View {
    @StateObject private var chatterManager = CommunityChatterManager()
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom Tab Picker
                Picker("", selection: $selectedTab) {
                    Text("Lounge").tag(0)
                    Text("[CxT] Café").tag(1)
                    Text("Events").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content
                TabView(selection: $selectedTab) {
                    LoungeSpaceView(chatterManager: chatterManager)
                        .tag(0)
                    
                    CxTCoffeeShopView(chatterManager: chatterManager)
                        .tag(1)
                    
                    LoungeEventsView(chatterManager: chatterManager)
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Community Chatter")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct LoungeSpaceView: View {
    @ObservedObject var chatterManager: CommunityChatterManager
    @EnvironmentObject var appState: AppState
    @State private var selectedLounge: CommunityLounge?
    @State private var showFeedback = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(chatterManager.lounges) { lounge in
                    VStack(alignment: .leading, spacing: 16) {
                        // Lounge Header
                        HStack {
                            VStack(alignment: .leading) {
                                Text(lounge.name)
                                    .font(.title2)
                                    .bold()
                                
                                HStack {
                                    Image(systemName: "location.fill")
                                        .font(.caption)
                                    Text(lounge.location)
                                        .font(.caption)
                                }
                                .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Open")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                                
                                Text(lounge.operatingHours.displayString)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 2)
                        
                        // Occupancy
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Current Occupancy")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Text("\(lounge.currentOccupancy)/\(lounge.capacity)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray5))
                                        .frame(height: 8)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(occupancyColor(lounge.occupancyPercentage))
                                        .frame(width: geometry.size.width * CGFloat(lounge.occupancyPercentage / 100), height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Zones
                        Text("Available Zones")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(lounge.zones) { zone in
                            ZoneCardView(zone: zone, lounge: lounge, chatterManager: chatterManager)
                        }
                        
                        // Amenities
                        Text("Amenities")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(lounge.amenities) { amenity in
                                AmenityCardView(amenity: amenity)
                            }
                        }
                    }
                    .padding()
                }
                
                // Feedback Button
                Button {
                    showFeedback = true
                } label: {
                    Label("Share Feedback", systemImage: "bubble.left.and.bubble.right")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView(chatterManager: chatterManager)
        }
    }
    
    private func occupancyColor(_ percentage: Double) -> Color {
        if percentage < 50 {
            return .green
        } else if percentage < 80 {
            return .orange
        } else {
            return .red
        }
    }
}

struct ZoneCardView: View {
    let zone: CommunityLounge.LoungeZone
    let lounge: CommunityLounge
    @ObservedObject var chatterManager: CommunityChatterManager
    
    var body: some View {
        HStack {
            Image(systemName: zone.type.icon)
                .font(.title2)
                .foregroundColor(zone.isOccupied ? .secondary : .blue)
                .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(zone.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("\(zone.seatingCapacity) seats")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    ForEach(zone.features.prefix(2), id: \.self) { feature in
                        Text(feature)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            VStack {
                if zone.isOccupied {
                    Text("Occupied")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                } else {
                    Button("Reserve") {
                        chatterManager.reserveZone(zone, in: lounge)
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
        .padding(.horizontal)
    }
}

struct AmenityCardView: View {
    let amenity: CommunityLounge.Amenity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: amenity.type.icon)
                    .foregroundColor(amenity.type.color)
                Spacer()
                if amenity.isAvailable {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
            
            Text(amenity.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
        }
        .padding()
        .frame(height: 80)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

struct CxTCoffeeShopView: View {
    @ObservedObject var chatterManager: CommunityChatterManager
    @EnvironmentObject var appState: AppState
    @State private var selectedCategory: CxTCoffeeShop.MenuItem.Category?
    @State private var cart: [CxTCoffeeShop.Order.OrderItem] = []
    @State private var showCart = false
    
    var filteredMenu: [CxTCoffeeShop.MenuItem] {
        if let category = selectedCategory {
            return chatterManager.getMenuByCategory(category)
        }
        return chatterManager.coffeeMenu
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(CxTCoffeeShop.companyName)
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Premium coffee and refreshments in your workplace")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Active Orders
                if let userId = appState.currentUser?.id.uuidString,
                   !chatterManager.getActiveOrders(for: userId).isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Orders")
                            .font(.headline)
                        
                        ForEach(chatterManager.getActiveOrders(for: userId)) { order in
                            ActiveOrderCard(order: order)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CategoryFilterButton(
                            title: "All",
                            isSelected: selectedCategory == nil,
                            action: { selectedCategory = nil }
                        )
                        
                        ForEach(CxTCoffeeShop.MenuItem.Category.allCases, id: \.self) { category in
                            CategoryFilterButton(
                                title: category.rawValue,
                                icon: category.icon,
                                isSelected: selectedCategory == category,
                                action: { selectedCategory = category }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Menu Items
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(filteredMenu) { item in
                        MenuItemCard(item: item) {
                            addToCart(item)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .overlay(alignment: .bottom) {
            if !cart.isEmpty {
                Button {
                    showCart = true
                } label: {
                    HStack {
                        Image(systemName: "cart.fill")
                        Text("View Cart (\(cart.count))")
                        Spacer()
                        Text(formatPrice(cartTotal))
                    }
                    .padding()
                    .background(Color.brown)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showCart) {
            CartView(cart: $cart, chatterManager: chatterManager)
        }
    }
    
    private func addToCart(_ item: CxTCoffeeShop.MenuItem) {
        let orderItem = CxTCoffeeShop.Order.OrderItem(
            id: UUID(),
            menuItem: item,
            quantity: 1,
            customizations: []
        )
        cart.append(orderItem)
    }
    
    private var cartTotal: Decimal {
        cart.reduce(Decimal(0)) { $0 + $1.subtotal }
    }
    
    private func formatPrice(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: price as NSNumber) ?? "$0.00"
    }
}

struct CategoryFilterButton: View {
    let title: String
    var icon: String?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.brown : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

struct MenuItemCard: View {
    let item: CxTCoffeeShop.MenuItem
    let onAdd: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.brown.opacity(0.1))
                    .frame(height: 100)
                
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.brown)
            }
            
            Text(item.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
            
            Text(item.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Text(formatPrice(item.price))
                    .font(.headline)
                    .foregroundColor(.brown)
                
                Spacer()
                
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.brown)
                        .font(.title3)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }
    
    private func formatPrice(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: price as NSNumber) ?? "$0.00"
    }
}

struct ActiveOrderCard: View {
    let order: CxTCoffeeShop.Order
    
    var body: some View {
        HStack {
            Image(systemName: order.status.icon)
                .foregroundColor(order.status.color)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Order #\(order.id.uuidString.prefix(8))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(order.status.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("\(order.items.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formatPrice(order.totalAmount))
                .font(.headline)
        }
        .padding()
        .background(order.status.color.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func formatPrice(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: price as NSNumber) ?? "$0.00"
    }
}

struct CartView: View {
    @Binding var cart: [CxTCoffeeShop.Order.OrderItem]
    @ObservedObject var chatterManager: CommunityChatterManager
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var specialInstructions = ""
    
    var body: some View {
        NavigationView {
            List {
                Section("Items") {
                    ForEach(cart) { item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.menuItem.name)
                                    .font(.subheadline)
                                Text("Qty: \(item.quantity)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(formatPrice(item.subtotal))
                                .font(.subheadline)
                        }
                    }
                    .onDelete { indexSet in
                        cart.remove(atOffsets: indexSet)
                    }
                }
                
                Section("Special Instructions") {
                    TextField("Add any special requests...", text: $specialInstructions)
                }
                
                Section {
                    HStack {
                        Text("Total")
                            .font(.headline)
                        Spacer()
                        Text(formatPrice(cartTotal))
                            .font(.headline)
                    }
                }
            }
            .navigationTitle("Your Cart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Place Order") {
                        placeOrder()
                    }
                    .disabled(cart.isEmpty)
                }
            }
        }
    }
    
    private var cartTotal: Decimal {
        cart.reduce(Decimal(0)) { $0 + $1.subtotal }
    }
    
    private func placeOrder() {
        guard let userId = appState.currentUser?.id.uuidString else { return }
        
        _ = chatterManager.placeOrder(
            userId: userId,
            items: cart,
            specialInstructions: specialInstructions.isEmpty ? nil : specialInstructions
        )
        
        cart.removeAll()
        dismiss()
    }
    
    private func formatPrice(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: price as NSNumber) ?? "$0.00"
    }
}

struct LoungeEventsView: View {
    @ObservedObject var chatterManager: CommunityChatterManager
    @EnvironmentObject var appState: AppState
    @State private var showCreateEvent = false
    
    var body: some View {
        List {
            if !chatterManager.getTodayEvents().isEmpty {
                Section("Today") {
                    ForEach(chatterManager.getTodayEvents()) { event in
                        EventCardView(event: event, chatterManager: chatterManager)
                    }
                }
            }
            
            Section("Upcoming") {
                ForEach(chatterManager.getUpcomingEvents()) { event in
                    EventCardView(event: event, chatterManager: chatterManager)
                }
            }
        }
        .navigationTitle("Events")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreateEvent = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

struct EventCardView: View {
    let event: LoungeEvent
    @ObservedObject var chatterManager: CommunityChatterManager
    @EnvironmentObject var appState: AppState
    
    var isJoined: Bool {
        guard let userId = appState.currentUser?.id.uuidString else { return false }
        return event.attendees.contains(userId)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: event.eventType.icon)
                    .foregroundColor(.blue)
                
                Text(event.title)
                    .font(.headline)
            }
            
            Text(event.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Label(event.startTime, style: .time)
                    .font(.caption)
                
                Spacer()
                
                Label(event.location, systemImage: "location")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            
            HStack {
                Text("\(event.attendees.count) attending")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let spotsLeft = event.spotsLeft {
                    Text("• \(spotsLeft) spots left")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isJoined {
                    Text("Joined")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                } else if !event.isFull {
                    Button("Join") {
                        if let userId = appState.currentUser?.id.uuidString {
                            chatterManager.joinEvent(event, userId: userId)
                        }
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct FeedbackView: View {
    @ObservedObject var chatterManager: CommunityChatterManager
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedCategory: EmployeeFeedback.FeedbackCategory = .overall
    @State private var rating = 5
    @State private var comment = ""
    @State private var isAnonymous = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(EmployeeFeedback.FeedbackCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                }
                
                Section("Rating") {
                    HStack {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .foregroundColor(star <= rating ? .yellow : .secondary)
                                .onTapGesture {
                                    rating = star
                                }
                        }
                    }
                }
                
                Section("Comments") {
                    TextEditor(text: $comment)
                        .frame(height: 100)
                }
                
                Section {
                    Toggle("Submit Anonymously", isOn: $isAnonymous)
                }
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        submitFeedback()
                    }
                    .disabled(comment.isEmpty)
                }
            }
        }
    }
    
    private func submitFeedback() {
        guard let userId = appState.currentUser?.id.uuidString else { return }
        
        let feedback = EmployeeFeedback(
            id: UUID(),
            userId: userId,
            category: selectedCategory,
            rating: rating,
            comment: comment,
            suggestions: [],
            timestamp: Date(),
            isAnonymous: isAnonymous
        )
        
        chatterManager.submitFeedback(feedback)
        dismiss()
    }
}

#Preview {
    CommunityChatterView()
        .environmentObject(AppState())
}
