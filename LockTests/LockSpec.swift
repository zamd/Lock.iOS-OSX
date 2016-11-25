// LockSpec.swift
//
// Copyright (c) 2016 Auth0 (http://auth0.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Quick
import Nimble
import Auth0
@testable import Lock

class LockSpec: QuickSpec {

    override func spec() {

        var lock: Lock!
        var authentication: Authentication!
        var webAuth: WebAuth!

        beforeEach {
            authentication = Auth0.authentication(clientId: clientId, domain: domain)
            webAuth = MockWebAuth()
            lock = Lock(authentication: authentication, webAuth: webAuth)
        }

        describe("options") {

            it("should allow settings options") {
                _ = lock.withOptions { $0.closable = true }
                expect(lock.options.closable) == true
            }

            it("should have defaults if never called") {
                expect(lock.options.closable) == false
            }

            it("should use the latest options") {
                _ = lock.withOptions { $0.closable = true }
                _ = lock.withOptions { $0.closable = false }
                expect(lock.options.closable) == false
            }

            it("should return itself") {
                expect(lock.withOptions { _ in } ) == lock
            }
        }

        describe("on") {

            it("should keep callback") {
                var called = false
                let callback: Lock.AuthenticationCallback = { _ in called = true }
                _ = lock.on(callback)
                lock.callback(.cancelled)
                expect(called) == true
            }

            it("should return itself") {
                expect(lock.on { _ in } ) == lock
            }
        }

        describe("withConnections") {

            it("should allow settings connections") {
                _ = lock.withConnections { $0.database(name: "MyDB", requiresUsername: false) }
                expect(lock.connections.database?.name) == "MyDB"
            }

            it("should have defaults if never called") {
                expect(lock.connections.database).to(beNil())
            }

            it("should use the latest options") {
                _ = lock.withConnections { $0.database(name: "MyDB", requiresUsername: false) }
                _ = lock.withConnections { $0.database(name: "AnotherDB", requiresUsername: false) }
                expect(lock.connections.database?.name) == "AnotherDB"
            }

            it("should return itself") {
                expect(lock.withConnections { _ in } ) == lock
            }

        }

        describe("present") {

            var controller: MockController!

            beforeEach {
                controller = MockController()
            }

            it("should present lock viewcontroller") {
                lock.present(from: controller)
                expect(controller.presented).notTo(beNil())
            }

            it("should fail if options are invalid") {
                _ = lock.withOptions { $0.allow = [] }
                waitUntil { done in
                    lock
                        .on {
                            expect($0).to(beErrorResult())
                            done()
                        }
                        .present(from: controller)
                }
            }

        }

        it("should allow to resume Auth") {
            expect(Lock.resumeAuth(.a0_url("samples.auth0.com"), options: [:])) == false
        }

    }

}