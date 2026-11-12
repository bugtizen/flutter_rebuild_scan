import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'example_gallery.dart';

void main() => runApp(const ExamplesApp());

/// All examples run locally, without a server or additional setup.
class ExamplesApp extends StatelessWidget {
  const ExamplesApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Rebuild Scan examples',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
    home: const ExampleGallery(),
  );
}

@Preview(name: 'Examples gallery', size: Size(390, 844))
Widget galleryPreview() => const ExamplesApp();
