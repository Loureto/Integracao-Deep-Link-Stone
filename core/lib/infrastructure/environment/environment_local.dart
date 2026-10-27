import '../../domain/domain.dart';
import 'environment_dictionary.dart';

class EnvironmentLocal implements Environment {
  const EnvironmentLocal._();

  static final instance = EnvironmentLocal._();

  @override
  String get cieloClientID => const String.fromEnvironment(EnvironmentDictionary.cieloClientID);

  @override
  String get cieloAccessToken => const String.fromEnvironment(EnvironmentDictionary.cieloAccessToken);
}
