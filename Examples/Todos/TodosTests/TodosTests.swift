import ComposableArchitecture
import XCTest

@testable import Todos

class TodosTests: XCTestCase {
  var events: [AnalyticsClient.Event] = []
  let scheduler = DispatchQueue.testScheduler

  func testAddTodo() {
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: AppEnvironment(
        analytics: .failing,
        mainQueue: .unimplemented,
        uuid: UUID.incrementing
      )
    )

    store.assert(
      .send(.addTodoButtonTapped) {
        $0.todos.insert(
          Todo(
            description: "",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            isComplete: false
          ),
          at: 0
        )
      },
      .send(.addTodoButtonTapped) {
        $0.todos.insert(
          Todo(
            description: "",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            isComplete: false
          ),
          at: 0
        )
      }
    )
  }

  func testEditTodo() {
    let state = AppState(
      todos: [
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        )
      ]
    )
    let store = TestStore(
      initialState: state,
      reducer: appReducer,
      environment: AppEnvironment(
        analytics: .failing,
        mainQueue: .unimplemented,
        uuid: UUID.failing
      )
    )

    store.assert(
      .send(
        .todo(id: state.todos[0].id, action: .textFieldChanged("Learn Composable Architecture"))
      ) {
        $0.todos[0].description = "Learn Composable Architecture"
      }
    )
  }

  func testCompleteTodo() {
    let state = AppState(
      todos: [
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: false
        ),
      ]
    )
    let store = TestStore(
      initialState: state,
      reducer: appReducer,
      environment: AppEnvironment(
        analytics: .failing,
        mainQueue: self.scheduler.eraseToAnyScheduler(),
        uuid: UUID.failing
      )
    )

    store.assert(
      .send(.todo(id: state.todos[0].id, action: .checkBoxToggled)) {
        $0.todos[0].isComplete = true
      },
      .do { self.scheduler.advance(by: 1) },
      .receive(.sortCompletedTodos) {
        $0.todos = [
          $0.todos[1],
          $0.todos[0],
        ]
      }
    )
  }

  func testCompleteTodoDebounces() {
    let state = AppState(
      todos: [
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: false
        ),
      ]
    )
    let store = TestStore(
      initialState: state,
      reducer: appReducer,
      environment: AppEnvironment(
        analytics: .failing,
        mainQueue: self.scheduler.eraseToAnyScheduler(),
        uuid: UUID.incrementing
      )
    )

    store.assert(
      .send(.todo(id: state.todos[0].id, action: .checkBoxToggled)) {
        $0.todos[0].isComplete = true
      },
      .do { self.scheduler.advance(by: 0.5) },
      .send(.todo(id: state.todos[0].id, action: .checkBoxToggled)) {
        $0.todos[0].isComplete = false
      },
      .do { self.scheduler.advance(by: 1) },
      .receive(.sortCompletedTodos)
    )
  }

  func testClearCompleted() {
    let state = AppState(
      todos: [
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: true
        ),
      ]
    )
    let store = TestStore(
      initialState: state,
      reducer: appReducer,
      environment: AppEnvironment(
        analytics: .test(onEvent: { event in self.events.append(event) }),
        mainQueue: self.scheduler.eraseToAnyScheduler(),
        uuid: UUID.incrementing
      )
    )

    store.assert(
      .send(.clearCompletedButtonTapped) {
        $0.todos = [
          $0.todos[0]
        ]
      }
    )
    XCTAssertEqual(events, [.init(name: "Cleared Completed Todos")])
  }

  func testDelete() {
    let state = AppState(
      todos: [
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: false
        ),
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
          isComplete: false
        ),
      ]
    )
    let store = TestStore(
      initialState: state,
      reducer: appReducer,
      environment: AppEnvironment(
        analytics: .test { self.events.append($0) },
        mainQueue: .unimplemented,
        uuid: UUID.failing
      )
    )

    store.assert(
      .send(.delete([1])) {
        $0.todos = [
          $0.todos[0],
          $0.todos[2],
        ]
      },
      .do {
        XCTAssertEqual(
          self.events,
          [
            .init(name: "Todo Deleted", properties: ["editMode": "inactive"]),
          ]
        )

      },
      .send(.editModeChanged(.active)) {
        $0.editMode = .active
      },
      .send(.delete([0])) {
        $0.todos = [
          $0.todos[1]
        ]
      }
    )
    XCTAssertEqual(
      events,
      [
        .init(name: "Todo Deleted", properties: ["editMode": "inactive"]),
        .init(name: "Todo Deleted", properties: ["editMode": "active"]),
      ]
    )
  }

  func testEditModeMoving() {
    let state = AppState(
      todos: [
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: false
        ),
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
          isComplete: false
        ),
      ]
    )
    let store = TestStore(
      initialState: state,
      reducer: appReducer,
      environment: AppEnvironment(
        analytics: .failing,
        mainQueue: self.scheduler.eraseToAnyScheduler(),
        uuid: UUID.incrementing
      )
    )

    store.assert(
      .send(.editModeChanged(.active)) {
        $0.editMode = .active
      },
      .send(.move([0], 2)) {
        $0.todos = [
          $0.todos[1],
          $0.todos[0],
          $0.todos[2],
        ]
      },
      .do { self.scheduler.advance(by: .milliseconds(100)) },
      .receive(.sortCompletedTodos)
    )
  }

  func testFilteredEdit() {
    let state = AppState(
      todos: [
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
          isComplete: false
        ),
        Todo(
          description: "",
          id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
          isComplete: true
        ),
      ]
    )
    let store = TestStore(
      initialState: state,
      reducer: appReducer,
      environment: AppEnvironment(
        analytics: .test(onEvent: { self.events.append($0) }),
        mainQueue: self.scheduler.eraseToAnyScheduler(),
        uuid: UUID.incrementing
      )
    )

    store.assert(
      .send(.filterPicked(.completed)) {
        $0.filter = .completed
      },
      .do {
        XCTAssertEqual(
          self.events,
          [.init(name: "Filter Changed", properties: ["filter": "completed"])]
        )
      },
      .send(.todo(id: state.todos[1].id, action: .textFieldChanged("Did this already"))) {
        $0.todos[1].description = "Did this already"
      }
    )
  }
}

extension UUID {
  // A deterministic, auto-incrementing "UUID" generator for testing.
  static var incrementing: () -> UUID {
    var uuid = 0
    return {
      defer { uuid += 1 }
      return UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012x", uuid))")!
    }
  }
  
  static let unimplemented: () -> UUID = { fatalError() }

//  static func failing(file: StaticString = #file, line: UInt = #line) -> () -> UUID {
//    {
//      XCTFail("UUID initializer is unimplemented.", file: file, line: line)
//      return UUID()
//    }
//  }

  static let failing: () -> UUID = {
    XCTFail("UUID initializer is unimplemented.")
    return UUID()
//    return UUID.init(uuidString: "deadbeef-dead-beef-dead-beefdeadbeef")!
  }
}

import Combine

extension Scheduler {
  static var unimplemented: AnySchedulerOf<Self> {
    AnyScheduler(
      minimumTolerance: { fatalError() },
      now: { fatalError() },
      scheduleImmediately: { _, _ in fatalError() },
      delayed: { _, _, _, _ in fatalError() },
      interval: { _, _, _, _, _ in fatalError() }
    )
  }
}

extension Effect {
  static func failing(_ title: String) -> Self {
    .fireAndForget {
      XCTFail("\(title): Effect is unimplemented")
    }
  }
}

extension AnalyticsClient {
  static let unimplemented = Self(
    track: { _ in fatalError() }
  )

  static let failing = Self(
    track: { event in
      .failing("AnalyticsClient.track")
    }
  )
  
  static func test(onEvent: @escaping (Event) -> Void) -> Self {
    Self(
      track: { event in
        .fireAndForget {
          onEvent(event)
        }
      }
    )
  }
}
