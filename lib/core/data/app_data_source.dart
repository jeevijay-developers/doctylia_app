enum AppDataSourceKind { mock, remote }

class AppDataSource {
  const AppDataSource.mock()
    : kind = AppDataSourceKind.mock,
      environmentName = 'mock';

  const AppDataSource.remote(this.environmentName)
    : kind = AppDataSourceKind.remote;

  final AppDataSourceKind kind;
  final String environmentName;

  bool get isMock => kind == AppDataSourceKind.mock;
}
