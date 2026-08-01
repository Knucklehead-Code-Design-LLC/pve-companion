import 'package:flutter/widgets.dart';

import 'app/pve_companion_app.dart';
import 'app/pve_companion_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final PveCompanionController controller =
      await PveCompanionController.create();
  runApp(PveCompanionApp(controller: controller));
}
