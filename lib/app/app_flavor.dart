enum AppFlavor { mock, staging, production }

extension AppFlavorX on AppFlavor {
  bool get usesMockData => this == AppFlavor.mock;
}
