import AuthenticationClient
import ComposableArchitecture
import Dispatch
import TwoFactorCore

public struct Login: ReducerProtocol {
  public struct State: Hashable {
    public var alert: AlertState<Action>?
    public var email = ""
    public var isFormValid = false
    public var isLoginRequestInFlight = false
    public var password = ""
    public var twoFactor: TwoFactor.State?

    public init() {}
  }

  public enum Action: Hashable {
    case alertDismissed
    case emailChanged(String)
    case passwordChanged(String)
    case loginButtonTapped
    case loginResponse(TaskResult<AuthenticationResponse>)
    case twoFactor(TwoFactor.Action)
    case twoFactorDismissed
  }

  @Dependency(\.authenticationClient) var authenticationClient
  @Dependency(\.mainQueue) var mainQueue

  private enum TwoFactorTearDownToken {}

  public init() {}

  public var body: some ReducerProtocol<State, Action> {
    Pullback(state: \.twoFactor, action: /Action.twoFactor) {
      IfLetReducer {
        TwoFactor(tearDownToken: TwoFactorTearDownToken.self)
      }
    }

    Reduce { state, action in
      switch action {
      case .alertDismissed:
        state.alert = nil
        return .none

      case let .emailChanged(email):
        state.email = email
        state.isFormValid = !state.email.isEmpty && !state.password.isEmpty
        return .none

      case let .loginResponse(.success(response)):
        state.isLoginRequestInFlight = false
        if response.twoFactorRequired {
          state.twoFactor = .init(token: response.token)
        }
        return .none

      case let .loginResponse(.failure(error)):
        state.alert = .init(title: TextState(error.localizedDescription))
        state.isLoginRequestInFlight = false
        return .none

      case let .passwordChanged(password):
        state.password = password
        state.isFormValid = !state.email.isEmpty && !state.password.isEmpty
        return .none

      case .loginButtonTapped:
        state.isLoginRequestInFlight = true
        return .task { [email = state.email, password = state.password] in
          .loginResponse(
            await .init {
              try await self.authenticationClient.login(
                .init(email: email, password: password)
              )
            }
          )
        }

      case .twoFactor:
        return .none

      case .twoFactorDismissed:
        state.twoFactor = nil
        return .cancel(id: TwoFactorTearDownToken.self)
      }
    }
  }
}
