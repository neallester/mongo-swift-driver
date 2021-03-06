@testable import MongoSwift
import Nimble
import XCTest

import libmongoc

final class ReadWriteConcernTests: XCTestCase {
    static var allTests: [(String, (ReadWriteConcernTests) -> () throws -> Void)] {
        return [
            ("testReadConcernType", testReadConcernType),
            ("testClientReadConcern", testClientReadConcern),
            ("testDatabaseReadConcern", testDatabaseReadConcern),
            ("testOperationReadConcerns", testOperationReadConcerns)
        ]
    }

    override func setUp() {
        self.continueAfterFailure = false
    }

    func testReadConcernType() throws {
        // check level var works as expected
        let rc = ReadConcern(.majority)
        expect(rc.level).to(equal("majority"))

        // test copy init
        let rc2 = ReadConcern(from: rc)
        expect(rc2.level).to(equal("majority"))

        // test empty init
        let rc3 = ReadConcern()
        expect(rc3.level).to(beNil())

        // test init from doc
        let rc4 = ReadConcern(["level": "majority"])
        expect(rc4.level).to(equal("majority"))

    }

    func testClientReadConcern() throws {
        // create a client with no options and check its RC
        let client1 = try MongoClient()
        // expect the readConcern property to exist with a nil level
        expect(client1.readConcern).to(beNil())

        // expect that a DB created from this client inherits its unset RC 
        let db1 = try client1.db("test")
        expect(db1.readConcern).to(beNil())

        // expect that a DB created from this client can override the client's unset RC
        let db2 = try client1.db("test", options: DatabaseOptions(readConcern: ReadConcern(.majority)))
        expect(db2.readConcern?.level).to(equal("majority"))

        client1.close()

        // create a client with local read concern and check its RC
        let client2 = try MongoClient(options: ClientOptions(readConcern: ReadConcern(.local)))
        // although local is default, if it is explicitly provided it should be set
        expect(client2.readConcern?.level).to(equal("local"))

        // expect that a DB created from this client inherits its local RC 
        let db3 = try client2.db("test")
        expect(db3.readConcern?.level).to(equal("local"))

        // expect that a DB created from this client can override the client's local RC
        let db4 = try client2.db("test", options: DatabaseOptions(readConcern: ReadConcern(.majority)))
        expect(db4.readConcern?.level).to(equal("majority"))

        client2.close()

        // create a client with majority read concern and check its RC
        let client3 = try MongoClient(options: ClientOptions(readConcern: ReadConcern(.majority)))
        expect(client3.readConcern?.level).to(equal("majority"))

        // expect that a DB created from this client can override the client's majority RC with an unset one
        let db5 = try client3.db("test", options: DatabaseOptions(readConcern: ReadConcern()))
        expect(db5.readConcern).to(beNil())

        client3.close()
    }

    func testDatabaseReadConcern() throws {
        let client = try MongoClient()

        let db1 = try client.db("test")
        defer {try? db1.drop() }

        // expect that a collection created from a DB with unset RC also has unset RC
        var coll1 = try db1.createCollection("coll1")
        expect(coll1.readConcern).to(beNil())

        // expect that a collection retrieved from a DB with unset RC also has unset RC
        coll1 = try db1.collection("coll1")
        expect(coll1.readConcern).to(beNil())

        // expect that a collection created from a DB with unset RC can override the DB's RC
        var coll2 = try db1.createCollection("coll2", options: CreateCollectionOptions(readConcern: ReadConcern(.local)))
        expect(coll2.readConcern?.level).to(equal("local"))

        // expect that a collection retrieved from a DB with unset RC can override the DB's RC
        coll2 = try db1.collection("coll2", options: CollectionOptions(readConcern: ReadConcern(.local)))
        expect(coll2.readConcern?.level).to(equal("local"))

        try db1.drop()

        let db2 = try client.db("test", options: DatabaseOptions(readConcern: ReadConcern(.local)))
        defer { try? db2.drop() }

        // expect that a collection created from a DB with local RC also has local RC
        var coll3 = try db2.createCollection("coll3")
        expect(coll3.readConcern?.level).to(equal("local"))

        // expect that a collection retrieved from a DB with local RC also has local RC
        coll3 = try db2.collection("coll3")
        expect(coll3.readConcern?.level).to(equal("local"))

        // expect that a collection created from a DB with local RC can override the DB's RC
        var coll4 = try db2.createCollection("coll4", options: CreateCollectionOptions(readConcern: ReadConcern(.majority)))
        expect(coll4.readConcern?.level).to(equal("majority"))

        // expect that a collection retrieved from a DB with local RC can override the DB's RC
        coll4 = try db2.collection("coll4", options: CollectionOptions(readConcern: ReadConcern(.majority)))
        expect(coll4.readConcern?.level).to(equal("majority"))
    }

    func testOperationReadConcerns() throws {
        // setup a collection 
        let client = try MongoClient()
        let db = try client.db("test")
        defer { try? db.drop() }
        let coll = try db.createCollection("coll1")

        let command: Document = ["count": "coll1"]

        // run command with a valid readConcern
        let options1 = RunCommandOptions(readConcern: ReadConcern(.local))
        let res1 = try db.runCommand(command, options: options1)
        expect(res1["ok"] as? Double).to(equal(1.0))

        // run command with an empty readConcern
        let options2 = RunCommandOptions(readConcern: ReadConcern())
        let res2 = try db.runCommand(command, options: options2)
        expect(res2["ok"] as? Double).to(equal(1.0))

        // running command with an invalid RC level should throw
        let options3 = RunCommandOptions(readConcern: ReadConcern("blah"))
        expect(try db.runCommand(command, options: options3)).to(throwError())

        // try various command + read concern pairs to make sure they work
        expect(try coll.find(options: FindOptions(readConcern: ReadConcern(.local)))).toNot(throwError())

        expect(try coll.aggregate([["$project": ["a": 1] as Document]],
            options: AggregateOptions(readConcern: ReadConcern(.majority)))).toNot(throwError())

        expect(try coll.count(options: CountOptions(readConcern: ReadConcern(.majority)))).toNot(throwError())

        expect(try coll.distinct(fieldName: "a",
            options: DistinctOptions(readConcern: ReadConcern(.local)))).toNot(throwError())
    }

    func testConnectionStrings() throws {
        let csPath = "\(self.getSpecsPath())/read-write-concern/tests/connection-string"
        let testFiles = try FileManager.default.contentsOfDirectory(atPath: csPath).filter { $0.hasSuffix(".json") }
        for filename in testFiles {
            let testFilePath = URL(fileURLWithPath: "\(csPath)/\(filename)")
            let asDocument = try Document(fromJSONFile: testFilePath)
            let tests: [Document] = try asDocument.get("tests")
            for test in tests {
                let description: String = try test.get("description")
                // skipping because C driver does not comply with these; see CDRIVER-2621
                if description.lowercased().contains("wtimeoutms") { continue }
                let uri: String = try test.get("uri")
                let valid: Bool = try test.get("valid")
                if valid {
                    let client = try MongoClient(connectionString: uri)
                    if let readConcern = test["readConcern"] as? Document {
                        let rc = ReadConcern(readConcern)
                        if rc.isDefault {
                            expect(client.readConcern).to(beNil())
                        } else {
                            expect(client.readConcern).to(equal(rc))
                        }
                    } else if let writeConcern = test["writeConcern"] as? Document {
                        // TODO SWIFT-30: verify the writeconcern matches that on the client
                    }
                } else {
                    expect(try MongoClient(connectionString: uri)).to(throwError())
                }
            }
        }
    }

    func testDocuments() throws {
        let docsPath = "\(self.getSpecsPath())/read-write-concern/tests/document"
        let testFiles = try FileManager.default.contentsOfDirectory(atPath: docsPath).filter { $0.hasSuffix(".json") }
        for filename in testFiles {
            let testFilePath = URL(fileURLWithPath: "\(docsPath)/\(filename)")
            let asDocument = try Document(fromJSONFile: testFilePath)
            let tests: [Document] = try asDocument.get("tests")
            for test in tests {
                let description: String = try test.get("description")
                // skipping because C driver does not comply with these; see CDRIVER-2621
                if ["WTimeoutMS as an invalid number", "W as an invalid number"].contains(description) { continue }
                let valid: Bool = try test.get("valid")
                if let rcToUse = test["readConcern"] as? Document {
                    let rc = ReadConcern(rcToUse)
                    let rcToSend = ReadConcern(test["readConcernDocument"] as! Document)
                    expect(rcToSend).to(equal(rc))
                } else if let wcToUse = test["writeConcern"] as? Document {
                    // TODO SWIFT-30: encode the write concern and confirm it matches the expected one
                }
            }
        }
    }
}
