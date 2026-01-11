//
//  CommunityChatter.swift
//  WorkSOPro
//
//  Model for Community Chatter - Physical lounge space management
//

import Foundation
import SwiftUI

struct CommunityLounge: Identifiable, Codable {
    let id: UUID
    var name: String
    var location: String
    var capacity: Int
    var amenities: [Amenity]
    var zones: [LoungeZone]
    var isAvailable: Bool
    var currentOccupancy: Int
    var operatingHours: OperatingHours
    
    struct Amenity: Codable, Identifiable {
        let id: UUID
        var name: String
        var type: AmenityType
        var isAvailable: Bool
        var description: String
        
        enum AmenityType: String, Codable, CaseIterable {
            case seating = "Comfortable Seating"
            case whiteboard = "Interactive Whiteboard"
            case digitalScreen = "Digital Screen"
            case coffeeStation = "Coffee Station"
            case snackBar = "Snack Bar"
            case bookshelf = "Library/Books"
            case gameArea = "Board Games"
            case plants = "Indoor Plants"
            case music = "Background Music"
            case naturalLight = "Natural Lighting"
            
            var icon: String {
                switch self {
                case .seating: return "sofa"
                case .whiteboard: return "pencil.and.outline"
                case .digitalScreen: return "tv"
                case .coffeeStation: return "cup.and.saucer.fill"
                case .snackBar: return "fork.knife"
                case .bookshelf: return "books.vertical.fill"
                case .gameArea: return "dice.fill"
                case .plants: return "leaf.fill"
                case .music: return "music.note"
                case .naturalLight: return "sun.max.fill"
                }
            }
            
            var color: Color {
                switch self {
                case .seating: return .blue
                case .whiteboard: return .purple
                case .digitalScreen: return .indigo
                case .coffeeStation: return .brown
                case .snackBar: return .orange
                case .bookshelf: return .green
                case .gameArea: return .red
                case .plants: return .green
                case .music: return .pink
                case .naturalLight: return .yellow
                }
            }
        }
        
        init(id: UUID = UUID(), name: String, type: AmenityType, isAvailable: Bool = true, description: String) {
            self.id = id
            self.name = name
            self.type = type
            self.isAvailable = isAvailable
            self.description = description
        }
    }
    
    struct LoungeZone: Codable, Identifiable {
        let id: UUID
        var name: String
        var type: ZoneType
        var seatingCapacity: Int
        var features: [String]
        var isOccupied: Bool
        
        enum ZoneType: String, Codable, CaseIterable {
            case quietZone = "Quiet Zone"
            case collaborationHub = "Collaboration Hub"
            case cafeArea = "Café Area"
            case gameCorner = "Game Corner"
            case readingNook = "Reading Nook"
            case standupArea = "Standup Meeting Area"
            case winddownSpace = "Winddown Space"
            
            var icon: String {
                switch self {
                case .quietZone: return "moon.zzz.fill"
                case .collaborationHub: return "person.3.fill"
                case .cafeArea: return "cup.and.saucer.fill"
                case .gameCorner: return "gamecontroller.fill"
                case .readingNook: return "book.fill"
                case .standupArea: return "bubble.left.and.bubble.right.fill"
                case .winddownSpace: return "sparkles"
                }
            }
        }
        
        init(id: UUID = UUID(), name: String, type: ZoneType, seatingCapacity: Int, features: [String], isOccupied: Bool = false) {
            self.id = id
            self.name = name
            self.type = type
            self.seatingCapacity = seatingCapacity
            self.features = features
            self.isOccupied = isOccupied
        }
    }
    
    struct OperatingHours: Codable {
        var openTime: String // "08:00"
        var closeTime: String // "20:00"
        var isOpen247: Bool
        
        var displayString: String {
            isOpen247 ? "Open 24/7" : "\(openTime) - \(closeTime)"
        }
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        location: String,
        capacity: Int,
        amenities: [Amenity],
        zones: [LoungeZone],
        isAvailable: Bool = true,
        currentOccupancy: Int = 0,
        operatingHours: OperatingHours
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.capacity = capacity
        self.amenities = amenities
        self.zones = zones
        self.isAvailable = isAvailable
        self.currentOccupancy = currentOccupancy
        self.operatingHours = operatingHours
    }
    
    var occupancyPercentage: Double {
        guard capacity > 0 else { return 0 }
        return Double(currentOccupancy) / Double(capacity) * 100
    }
    
    var availableSeats: Int {
        max(0, capacity - currentOccupancy)
    }
}

// MARK: - CxT Roasting Company Integration

struct CxTCoffeeShop {
    static let companyName = "[CxT] Roasting Company"
    
    struct MenuItem: Identifiable, Codable {
        let id: UUID
        var name: String
        var category: Category
        var description: String
        var price: Decimal
        var isAvailable: Bool
        var imageName: String?
        var nutritionInfo: NutritionInfo?
        var customizationOptions: [String]
        
        enum Category: String, Codable, CaseIterable {
            case espresso = "Espresso Drinks"
            case coffee = "Brewed Coffee"
            case tea = "Tea"
            case coldBrew = "Cold Brew"
            case specialty = "Specialty Drinks"
            case snacks = "Snacks"
            case pastries = "Pastries"
            
            var icon: String {
                switch self {
                case .espresso: return "cup.and.saucer.fill"
                case .coffee: return "drop.fill"
                case .tea: return "leaf.fill"
                case .coldBrew: return "snow"
                case .specialty: return "star.fill"
                case .snacks: return "fork.knife"
                case .pastries: return "birthday.cake.fill"
                }
            }
        }
        
        struct NutritionInfo: Codable {
            var calories: Int
            var caffeine: Int // mg
            var sugar: Int // g
        }
        
        init(
            id: UUID = UUID(),
            name: String,
            category: Category,
            description: String,
            price: Decimal,
            isAvailable: Bool = true,
            imageName: String? = nil,
            nutritionInfo: NutritionInfo? = nil,
            customizationOptions: [String] = []
        ) {
            self.id = id
            self.name = name
            self.category = category
            self.description = description
            self.price = price
            self.isAvailable = isAvailable
            self.imageName = imageName
            self.nutritionInfo = nutritionInfo
            self.customizationOptions = customizationOptions
        }
    }
    
    struct Order: Identifiable, Codable {
        let id: UUID
        var userId: String
        var items: [OrderItem]
        var totalAmount: Decimal
        var status: OrderStatus
        var orderTime: Date
        var pickupTime: Date?
        var specialInstructions: String?
        
        struct OrderItem: Codable, Identifiable {
            let id: UUID
            var menuItem: MenuItem
            var quantity: Int
            var customizations: [String]
            
            var subtotal: Decimal {
                menuItem.price * Decimal(quantity)
            }
        }
        
        enum OrderStatus: String, Codable {
            case pending = "Pending"
            case preparing = "Preparing"
            case ready = "Ready for Pickup"
            case completed = "Completed"
            case cancelled = "Cancelled"
            
            var icon: String {
                switch self {
                case .pending: return "clock"
                case .preparing: return "flame"
                case .ready: return "checkmark.circle"
                case .completed: return "checkmark.circle.fill"
                case .cancelled: return "xmark.circle"
                }
            }
            
            var color: Color {
                switch self {
                case .pending: return .orange
                case .preparing: return .blue
                case .ready: return .green
                case .completed: return .secondary
                case .cancelled: return .red
                }
            }
        }
    }
    
    // Popular menu items
    static let popularItems: [MenuItem] = [
        MenuItem(
            name: "CxT Signature Espresso",
            category: .espresso,
            description: "Rich, bold espresso with notes of chocolate and caramel",
            price: 3.50,
            nutritionInfo: MenuItem.NutritionInfo(calories: 5, caffeine: 75, sugar: 0),
            customizationOptions: ["Single", "Double", "Triple"]
        ),
        MenuItem(
            name: "Vanilla Latte",
            category: .espresso,
            description: "Smooth espresso with steamed milk and vanilla syrup",
            price: 4.50,
            nutritionInfo: MenuItem.NutritionInfo(calories: 190, caffeine: 75, sugar: 18),
            customizationOptions: ["Hot", "Iced", "Extra Shot", "Oat Milk", "Almond Milk"]
        ),
        MenuItem(
            name: "Cold Brew Classic",
            category: .coldBrew,
            description: "Smooth, refreshing cold brew steeped for 16 hours",
            price: 4.00,
            nutritionInfo: MenuItem.NutritionInfo(calories: 5, caffeine: 200, sugar: 0),
            customizationOptions: ["Regular", "Large", "Add Cream", "Add Vanilla"]
        ),
        MenuItem(
            name: "Matcha Green Tea Latte",
            category: .tea,
            description: "Premium matcha with steamed milk",
            price: 5.00,
            nutritionInfo: MenuItem.NutritionInfo(calories: 140, caffeine: 70, sugar: 12),
            customizationOptions: ["Hot", "Iced", "Extra Matcha", "Coconut Milk"]
        ),
        MenuItem(
            name: "Energy Boost Smoothie",
            category: .specialty,
            description: "Banana, berries, spinach, and protein",
            price: 6.00,
            nutritionInfo: MenuItem.NutritionInfo(calories: 250, caffeine: 0, sugar: 22)
        ),
        MenuItem(
            name: "Chocolate Croissant",
            category: .pastries,
            description: "Buttery, flaky croissant with dark chocolate",
            price: 3.50,
            nutritionInfo: MenuItem.NutritionInfo(calories: 320, caffeine: 15, sugar: 18)
        ),
        MenuItem(
            name: "Protein Power Bar",
            category: .snacks,
            description: "Healthy snack with nuts, seeds, and dried fruit",
            price: 3.00,
            nutritionInfo: MenuItem.NutritionInfo(calories: 200, caffeine: 0, sugar: 10)
        )
    ]
}

struct LoungeEvent: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var eventType: EventType
    var startTime: Date
    var endTime: Date
    var location: String // Zone name
    var organizer: String
    var attendees: [String]
    var maxAttendees: Int?
    var isRecurring: Bool
    var recurrencePattern: RecurrencePattern?
    
    enum EventType: String, Codable, CaseIterable {
        case coffeeChat = "Coffee Chat"
        case gameNight = "Game Night"
        case bookClub = "Book Club"
        case wellness = "Wellness Session"
        case teamBuilding = "Team Building"
        case socialHour = "Social Hour"
        case birthday = "Birthday Celebration"
        case workshop = "Workshop"
        
        var icon: String {
            switch self {
            case .coffeeChat: return "cup.and.saucer"
            case .gameNight: return "dice"
            case .bookClub: return "book"
            case .wellness: return "heart"
            case .teamBuilding: return "person.3"
            case .socialHour: return "party.popper"
            case .birthday: return "birthday.cake"
            case .workshop: return "lightbulb"
            }
        }
    }
    
    enum RecurrencePattern: String, Codable {
        case daily = "Daily"
        case weekly = "Weekly"
        case biweekly = "Bi-weekly"
        case monthly = "Monthly"
    }
    
    var isFull: Bool {
        guard let max = maxAttendees else { return false }
        return attendees.count >= max
    }
    
    var spotsLeft: Int? {
        guard let max = maxAttendees else { return nil }
        return max - attendees.count
    }
}

struct EmployeeFeedback: Identifiable, Codable {
    let id: UUID
    var userId: String
    var category: FeedbackCategory
    var rating: Int // 1-5
    var comment: String
    var suggestions: [String]
    var timestamp: Date
    var isAnonymous: Bool
    
    enum FeedbackCategory: String, Codable, CaseIterable {
        case amenities = "Amenities"
        case cleanliness = "Cleanliness"
        case atmosphere = "Atmosphere"
        case coffee = "Coffee Quality"
        case events = "Events"
        case overall = "Overall Experience"
        
        var icon: String {
            switch self {
            case .amenities: return "star"
            case .cleanliness: return "sparkles"
            case .atmosphere: return "heart"
            case .coffee: return "cup.and.saucer"
            case .events: return "calendar"
            case .overall: return "hand.thumbsup"
            }
        }
    }
}
