//
//  EWSDBTests.swift
//  EWSDBTests
//
//  Created by Eric Schramm on 7/28/20.
//


import XCTest
@testable import EWSDB

final class EWSDBTests: XCTestCase {
    var dbManager: DBManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        dbManager = createManager()
    }

    override func tearDownWithError() throws {
        dbManager.nukeDatabase()
        try super.tearDownWithError()
    }
    
    func testDatabaseExists() throws {
        if !dbManager.createDatabaseIfNotExistAndOpen() {
            throw EWSDBTestError.other("Unable to create database, other tests may be inaccurate")
        }
    }
    
    func testFetch() throws {
        var person = Person(firstName: "Eric", lastName: "Schramm", weight: 123.456, age: 41, timeStamp: Date())
        let saveResult = person.save(dbManager: dbManager) as Result<Person>
        guard case .success(let savedPerson) = saveResult else {
            XCTFail("Save unsuccessful for Person")
            return
        }
        person = savedPerson
        
        //test fetch by record - exists
        let foundResult: Result<[Person]> = Person.fetch(for: ["1"], dbManager: dbManager)
        switch foundResult {
        case .success(let foundPerson):
            XCTAssertEqual(person, foundPerson[0])
        case .error(let error):
            XCTFail("Failed search - \(error)")
        }
        if case .error(let errorString) = foundResult {
            XCTAssert(false, "This search should succeed - \(errorString)")
        }
        
        //test fetch by record - not exists
        let notFoundResult: Result<[Person]> = Person.fetch(for: ["999"], dbManager: dbManager)
        switch notFoundResult {
        case .error(let errorString):
            XCTAssert(false, "This search should succed - \(errorString)")
        case .success(let founds):
            XCTAssert(founds.isEmpty, "This should be an empty array")
        }
    }
    
    func testWriteReadTypes() throws {
        let person = Person(firstName: "Eric", lastName: "Schramm", weight: 123.456, age: 41, timeStamp: Date())
        let savedResult: Result<Person> = person.save(dbManager: dbManager)
        switch savedResult {
        case .success(let savedPerson):
            XCTAssert(savedPerson.firstName == "Eric",  ".text      - String mismatch")
            XCTAssert(savedPerson.weight == 123.456,    ".numeric   - Double mismatch")
            XCTAssert(savedPerson.age == 41,            ".integer   - Int32 mismatch")
        case .error(let error):
            XCTAssert(true, error)
        }
        
        /*
         case text
         case numeric
         case integer
         case recordID
         case real
         case blob
         case dateTime
         case bool           // 0 or 1
         */
    }
    
    func testDeleteNetworked(dbManager: DBManager) throws {
        _ = dbManager.createDatabaseIfNotExistAndOpen()
        let friend1 = Person(firstName: "Eric", lastName: "Schramm", weight: 123.45, age: 41, timeStamp: Date())
        let friend1saveResult: Result<Person> = friend1.save(dbManager: dbManager)
        var friend1Saved: Person!
        switch friend1saveResult {
        case .error(let error):
            XCTAssert(false, "Should never happen, save should succeed. \(error)")
        case .success(let saved):
            friend1Saved = saved
        }
        let friend2 = Person(firstName: "Jennifer", lastName: "Schramm", weight: 100, age: 39, timeStamp: Date())
        let friend2saveResult: Result<Person> = friend2.save(dbManager: dbManager)
        var friend2Saved: Person!
        switch friend2saveResult {
        case .error(let error):
            XCTAssert(false, "Should never happen, save should succeed \(error)")
        case .success(let saved):
            friend2Saved = saved
        }
        let friendList = FriendList(listName: "CheesyFriends", friend1: friend1Saved.zID!, friend2: friend2Saved.zID!)
        let _: Result<FriendList> = friendList.save(dbManager: dbManager)
        
        let delete1 = friend1Saved.delete(dbManager: dbManager)
        switch delete1 {
        case .error(_):
            XCTAssert(true, "expected behavior")
        case .success:
            XCTAssert(false, "the deletion should have been aborted due to a networked record")
        }
        
        let delete2 = friend2Saved.delete(dbManager: dbManager)
        switch delete2 {
        case .error(_):
            XCTAssert(false, "the deletion should have been permitted")
        case .success:
            XCTAssert(true, "expected behavior")
        }
    }


    static var allTests = [
        ("testDatabaseExists", testDatabaseExists),
        ("testFetch", testFetch),
        ("testWriteReadTypes", testWriteReadTypes)
    ]
}


struct Person: DBModel, Equatable {
    
    static let firstNameField = DBField(keyName: "firstName", dbFieldName: nil, dataType: .text, constraints: [.notNull])
    static let lastNameField = DBField(keyName: "lastName", dbFieldName: nil, dataType: .text, constraints: [.notNull])
    static let weightField = DBField(keyName: "weight", dbFieldName: "WeightField", dataType: .real, constraints: [.notNull])
    static let ageField = DBField(keyName: "age", dbFieldName: nil, dataType: .integer, constraints: [.notNull])
    static let timeStampField = DBField(keyName: "timeStamp", dbFieldName: nil, dataType: .dateTime, constraints: [.notNull])
    
    static var table: DBTable {
        return DBTable(keyName: "Person", dbTableName: "People", indexes: [DBIndex(name: "idx_last_first", fields: [lastNameField, firstNameField], unique: true)])
    }
    
    static var fields: [DBField] {
        return [
            firstNameField,
            lastNameField,
            weightField,
            ageField,
            timeStampField
        ]
    }
    
    var dataDictionary: [String : Any] {
        return [
            "zID" : zID ?? NSNull(),
            "firstName" : firstName,
            "lastName" : lastName,
            "weight" : weight,
            "age" : age,
            "timeStamp" : timeStamp
        ]
    }
    
    static let zIDfieldOverride: String? = nil
    static var zIDfieldKeyOverride: String? = nil
    
    let zID: RecordID?
    let firstName: String
    let lastName: String
    let weight: Double
    let age: Int32
    let timeStamp: Date
    
    init?(dataDictionary: [String : Any]) {
        if let firstName = dataDictionary["firstName"] as? String,
            let lastName = dataDictionary["lastName"] as? String,
            let weight = dataDictionary["weight"] as? Double,
            let age = dataDictionary["age"] as? Int32,
            let timeStamp = dataDictionary["timeStamp"] as? Date
        {
            self.firstName = firstName
            self.lastName = lastName
            self.zID = dataDictionary["zID"] as? RecordID
            self.weight = weight
            self.age = age
            self.timeStamp = timeStamp
        } else {
            return nil
        }
    }
    
    init(firstName: String, lastName: String, weight: Double, age: Int32, timeStamp: Date) {
        self.firstName = firstName
        self.lastName = lastName
        self.zID = nil
        self.weight = weight
        self.age = age
        self.timeStamp = timeStamp
    }
}

struct FriendList: DBModel {
    static let listNameField = DBField(keyName: "listName", dbFieldName: nil, dataType: .text, constraints: [.notNull])
    static let friend1Field = DBField(keyName: "friend1", dbFieldName: nil, dataType: .recordID, constraints: [.notNull, .noDeletionIfNetworked(toTable: Person.table.dbTable())])
    static let friend2Field = DBField(keyName: "friend2", dbFieldName: nil, dataType: .recordID, constraints: [.notNull])
    
    static var table: DBTable {
        return DBTable(keyName: "FriendList", dbTableName: nil, indexes: [])
    }
    
    static var fields: [DBField] {
        return [
            listNameField,
            friend1Field,
            friend2Field
        ]
    }
    
    var dataDictionary: [String : Any] {
        return [
            "zID" : zID ?? NSNull(),
            "listName" : listName,
            "friend1" : friend1,
            "friend2" : friend2
        ]
    }
    
    static let zIDfieldOverride: String? = nil
    static var zIDfieldKeyOverride: String? = nil
    
    let zID: RecordID?
    let listName: String
    let friend1: RecordID
    let friend2: RecordID
    
    init?(dataDictionary: [String : Any]) {
        if let listName = dataDictionary["listName"] as? String,
            let friend1 = dataDictionary["friend1"] as? RecordID,
            let friend2 = dataDictionary["friend2"] as? RecordID
        {
            self.listName = listName
            self.friend1 = friend1
            self.friend2 = friend2
            self.zID = dataDictionary["zID"] as? RecordID
        } else {
            return nil
        }
    }
    
    init(listName: String, friend1: RecordID, friend2: RecordID) {
        self.listName = listName
        self.friend1 = friend1
        self.friend2 = friend2
        self.zID = nil
    }
}

func createManager() -> DBManager {
    let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
    let documentsDirectory = paths[0] as NSString
    let fileName = "TestDB.sqlite"
    let logFilePath = documentsDirectory.appendingPathComponent(fileName)
    return DBManager(filePath: logFilePath, models: [Person.self, FriendList.self])
}

enum EWSDBTestError: Error {
    case other(String)
}
