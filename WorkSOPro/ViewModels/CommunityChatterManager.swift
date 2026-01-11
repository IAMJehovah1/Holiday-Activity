//
//  CommunityChatterManager.swift
//  WorkSOPro
//
//  ViewModel for managing community lounge and CxT Coffee Shop
//

import Foundation
import Combine

class CommunityChatterManager: ObservableObject {
    @Published var lounges: [CommunityLounge] = []
    @Published var coffeeMenu: [CxTCoffeeShop.MenuItem] = []
    @Published var currentOrders: [CxTCoffeeShop.Order] = []
    @Published var upcomingEvents: [LoungeEvent] = []
    @Published var feedback: [EmployeeFeedback] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupDefaultLounge()
        loadCoffeeMenu()
        loadUpcomingEvents()
    }
    
    // MARK: - Lounge Management
    
    func checkInToLounge(_ lounge: CommunityLounge) {
        if let index = lounges.firstIndex(where: { $0.id == lounge.id }) {
            lounges[index].currentOccupancy += 1
            saveLounges()
        }
    }
    
    func checkOutFromLounge(_ lounge: CommunityLounge) {
        if let index = lounges.firstIndex(where: { $0.id == lounge.id }) {
            lounges[index].currentOccupancy = max(0, lounges[index].currentOccupancy - 1)
            saveLounges()
        }
    }
    
    func reserveZone(_ zone: CommunityLounge.LoungeZone, in lounge: CommunityLounge) {
        if let loungeIndex = lounges.firstIndex(where: { $0.id == lounge.id }),
           let zoneIndex = lounges[loungeIndex].zones.firstIndex(where: { $0.id == zone.id }) {
            lounges[loungeIndex].zones[zoneIndex].isOccupied = true
            saveLounges()
        }
    }
    
    func releaseZone(_ zone: CommunityLounge.LoungeZone, in lounge: CommunityLounge) {
        if let loungeIndex = lounges.firstIndex(where: { $0.id == lounge.id }),
           let zoneIndex = lounges[loungeIndex].zones.firstIndex(where: { $0.id == zone.id }) {
            lounges[loungeIndex].zones[zoneIndex].isOccupied = false
            saveLounges()
        }
    }
    
    func getAvailableZones(in lounge: CommunityLounge) -> [CommunityLounge.LoungeZone] {
        lounge.zones.filter { !$0.isOccupied }
    }
    
    // MARK: - CxT Coffee Shop
    
    func placeOrder(userId: String, items: [CxTCoffeeShop.Order.OrderItem], specialInstructions: String? = nil) -> CxTCoffeeShop.Order {
        let totalAmount = items.reduce(Decimal(0)) { $0 + $1.subtotal }
        
        let order = CxTCoffeeShop.Order(
            id: UUID(),
            userId: userId,
            items: items,
            totalAmount: totalAmount,
            status: .pending,
            orderTime: Date(),
            specialInstructions: specialInstructions
        )
        
        currentOrders.append(order)
        saveOrders()
        
        // Simulate order processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.updateOrderStatus(order.id, to: .preparing)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.updateOrderStatus(order.id, to: .ready)
        }
        
        return order
    }
    
    func updateOrderStatus(_ orderId: UUID, to status: CxTCoffeeShop.Order.OrderStatus) {
        if let index = currentOrders.firstIndex(where: { $0.id == orderId }) {
            currentOrders[index].status = status
            if status == .ready {
                currentOrders[index].pickupTime = Date()
            }
            saveOrders()
        }
    }
    
    func getActiveOrders(for userId: String) -> [CxTCoffeeShop.Order] {
        currentOrders.filter {
            $0.userId == userId && ($0.status == .pending || $0.status == .preparing || $0.status == .ready)
        }
    }
    
    func getMenuByCategory(_ category: CxTCoffeeShop.MenuItem.Category) -> [CxTCoffeeShop.MenuItem] {
        coffeeMenu.filter { $0.category == category && $0.isAvailable }
    }
    
    func getPopularItems() -> [CxTCoffeeShop.MenuItem] {
        Array(coffeeMenu.prefix(5))
    }
    
    // MARK: - Events
    
    func createEvent(_ event: LoungeEvent) {
        upcomingEvents.append(event)
        saveEvents()
    }
    
    func joinEvent(_ event: LoungeEvent, userId: String) {
        if let index = upcomingEvents.firstIndex(where: { $0.id == event.id }) {
            if !upcomingEvents[index].attendees.contains(userId) && !upcomingEvents[index].isFull {
                upcomingEvents[index].attendees.append(userId)
                saveEvents()
            }
        }
    }
    
    func leaveEvent(_ event: LoungeEvent, userId: String) {
        if let index = upcomingEvents.firstIndex(where: { $0.id == event.id }) {
            upcomingEvents[index].attendees.removeAll { $0 == userId }
            saveEvents()
        }
    }
    
    func getUpcomingEvents() -> [LoungeEvent] {
        upcomingEvents.filter { $0.startTime > Date() }.sorted { $0.startTime < $1.startTime }
    }
    
    func getTodayEvents() -> [LoungeEvent] {
        let calendar = Calendar.current
        let today = Date()
        return upcomingEvents.filter { calendar.isDate($0.startTime, inSameDayAs: today) }
    }
    
    // MARK: - Feedback
    
    func submitFeedback(_ feedback: EmployeeFeedback) {
        self.feedback.append(feedback)
        saveFeedback()
    }
    
    func getAverageRating(for category: EmployeeFeedback.FeedbackCategory) -> Double {
        let categoryFeedback = feedback.filter { $0.category == category }
        guard !categoryFeedback.isEmpty else { return 0 }
        
        let sum = categoryFeedback.reduce(0) { $0 + $1.rating }
        return Double(sum) / Double(categoryFeedback.count)
    }
    
    func getOverallSatisfaction() -> Double {
        guard !feedback.isEmpty else { return 0 }
        
        let sum = feedback.reduce(0) { $0 + $1.rating }
        return Double(sum) / Double(feedback.count)
    }
    
    // MARK: - Setup Default Content
    
    private func setupDefaultLounge() {
        let mainLounge = CommunityLounge(
            name: "Community Chatter Lounge",
            location: "Building A, 2nd Floor",
            capacity: 50,
            amenities: [
                CommunityLounge.Amenity(
                    name: "Luxury Seating",
                    type: .seating,
                    description: "Mix of comfortable couches, lounge chairs, and bean bags"
                ),
                CommunityLounge.Amenity(
                    name: "Collaboration Whiteboards",
                    type: .whiteboard,
                    description: "Interactive whiteboards for brainstorming and idea sharing"
                ),
                CommunityLounge.Amenity(
                    name: "Digital Display",
                    type: .digitalScreen,
                    description: "Large screens for presentations and sharing updates"
                ),
                CommunityLounge.Amenity(
                    name: "[CxT] Roasting Company Café",
                    type: .coffeeStation,
                    description: "Premium coffee, tea, and specialty drinks from CxT Roasting Company"
                ),
                CommunityLounge.Amenity(
                    name: "Snack Bar",
                    type: .snackBar,
                    description: "Fresh snacks, pastries, and healthy options"
                ),
                CommunityLounge.Amenity(
                    name: "Reading Library",
                    type: .bookshelf,
                    description: "Curated collection of business books, magazines, and leisure reading"
                ),
                CommunityLounge.Amenity(
                    name: "Game Zone",
                    type: .gameArea,
                    description: "Board games, cards, and puzzles for relaxation"
                ),
                CommunityLounge.Amenity(
                    name: "Indoor Garden",
                    type: .plants,
                    description: "Lush plants and greenery for a calming atmosphere"
                ),
                CommunityLounge.Amenity(
                    name: "Ambient Music System",
                    type: .music,
                    description: "Curated playlists for different moods and times of day"
                ),
                CommunityLounge.Amenity(
                    name: "Natural Lighting",
                    type: .naturalLight,
                    description: "Floor-to-ceiling windows with panoramic views"
                )
            ],
            zones: [
                CommunityLounge.LoungeZone(
                    name: "Quiet Retreat",
                    type: .quietZone,
                    seatingCapacity: 8,
                    features: ["Noise-dampening panels", "Soft lighting", "Privacy partitions"]
                ),
                CommunityLounge.LoungeZone(
                    name: "Innovation Hub",
                    type: .collaborationHub,
                    seatingCapacity: 12,
                    features: ["Large table", "Whiteboards", "Power outlets", "Video conferencing"]
                ),
                CommunityLounge.LoungeZone(
                    name: "[CxT] Café Corner",
                    type: .cafeArea,
                    seatingCapacity: 15,
                    features: ["High-top tables", "Bar seating", "Coffee counter", "Pastry display"]
                ),
                CommunityLounge.LoungeZone(
                    name: "Play Zone",
                    type: .gameCorner,
                    seatingCapacity: 8,
                    features: ["Game shelves", "Comfortable seating", "Large table"]
                ),
                CommunityLounge.LoungeZone(
                    name: "Book Nook",
                    type: .readingNook,
                    seatingCapacity: 6,
                    features: ["Cozy chairs", "Reading lamps", "Bookshelves"]
                ),
                CommunityLounge.LoungeZone(
                    name: "Quick Connect",
                    type: .standupArea,
                    seatingCapacity: 10,
                    features: ["Standing tables", "Pinboards", "Quick chat space"]
                ),
                CommunityLounge.LoungeZone(
                    name: "Zen Space",
                    type: .winddownSpace,
                    seatingCapacity: 6,
                    features: ["Meditation cushions", "Soft music", "Dim lighting", "Aromatherapy"]
                )
            ],
            operatingHours: CommunityLounge.OperatingHours(
                openTime: "07:00",
                closeTime: "20:00",
                isOpen247: false
            )
        )
        
        lounges = [mainLounge]
        saveLounges()
    }
    
    private func loadCoffeeMenu() {
        coffeeMenu = CxTCoffeeShop.popularItems
    }
    
    private func loadUpcomingEvents() {
        // Create some default events
        let now = Date()
        let calendar = Calendar.current
        
        upcomingEvents = [
            LoungeEvent(
                id: UUID(),
                title: "Morning Coffee Chat",
                description: "Start your day with casual conversation over CxT coffee",
                eventType: .coffeeChat,
                startTime: calendar.date(byAdding: .day, value: 1, to: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now)!)!,
                endTime: calendar.date(byAdding: .day, value: 1, to: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now)!)!,
                location: "[CxT] Café Corner",
                organizer: "HR Team",
                attendees: [],
                maxAttendees: 15,
                isRecurring: true,
                recurrencePattern: .daily
            ),
            LoungeEvent(
                id: UUID(),
                title: "Friday Game Night",
                description: "Unwind with board games and friendly competition",
                eventType: .gameNight,
                startTime: calendar.date(byAdding: .day, value: 5, to: calendar.date(bySettingHour: 17, minute: 30, second: 0, of: now)!)!,
                endTime: calendar.date(byAdding: .day, value: 5, to: calendar.date(bySettingHour: 19, minute: 30, second: 0, of: now)!)!,
                location: "Play Zone",
                organizer: "Social Committee",
                attendees: [],
                maxAttendees: 8,
                isRecurring: true,
                recurrencePattern: .weekly
            ),
            LoungeEvent(
                id: UUID(),
                title: "Wellness Wednesday",
                description: "Guided meditation and mindfulness session",
                eventType: .wellness,
                startTime: calendar.date(byAdding: .day, value: 3, to: calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)!)!,
                endTime: calendar.date(byAdding: .day, value: 3, to: calendar.date(bySettingHour: 12, minute: 30, second: 0, of: now)!)!,
                location: "Zen Space",
                organizer: "Wellness Team",
                attendees: [],
                maxAttendees: 6,
                isRecurring: true,
                recurrencePattern: .weekly
            )
        ]
        
        saveEvents()
    }
    
    // MARK: - Persistence
    
    private func saveLounges() {
        // In a real app, save to Core Data or CloudKit
        objectWillChange.send()
    }
    
    private func saveOrders() {
        // In a real app, save to Core Data or CloudKit
        objectWillChange.send()
    }
    
    private func saveEvents() {
        // In a real app, save to Core Data or CloudKit
        objectWillChange.send()
    }
    
    private func saveFeedback() {
        // In a real app, save to Core Data or CloudKit
        objectWillChange.send()
    }
}
