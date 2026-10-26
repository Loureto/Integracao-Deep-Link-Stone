import 'package:dependencies/dependencies.dart';
import 'package:example/app_binding.dart';
import 'package:flutter/material.dart';

import 'app_widget.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  AppBinding.binds(GetIt.instance);

  runApp(const AppWidget());
}
