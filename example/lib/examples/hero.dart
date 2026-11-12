import 'package:flutter/material.dart';
import 'package:flutter_rebuild_scan/flutter_rebuild_scan.dart';

/// A local navigator keeps both routes and the Hero overlay under the scanner.
class HeroExample extends StatefulWidget {
  const HeroExample({super.key});
  @override
  State<HeroExample> createState() => _HeroExampleState();
}

class _HeroExampleState extends State<HeroExample> {
  final controller = HeroController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 320,
    child: HeroControllerScope(
      controller: controller,
      child: Navigator(
        onGenerateRoute: (_) =>
            MaterialPageRoute<void>(builder: (_) => const _HeroStart()),
      ),
    ),
  );
}

class _HeroStart extends StatelessWidget {
  const _HeroStart();
  @override
  Widget build(BuildContext context) => Material(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _TrackedHero(size: 64),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const _HeroDetail())),
          child: const Text('Open Hero detail'),
        ),
      ],
    ),
  );
}

class _HeroDetail extends StatelessWidget {
  const _HeroDetail();
  @override
  Widget build(BuildContext context) => Material(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _TrackedHero(size: 120),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back to small Hero'),
        ),
      ],
    ),
  );
}

class _TrackedHero extends StatelessWidget {
  const _TrackedHero({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) {
    RebuildScan.mark(context, name: 'Hero $size');
    return Hero(
      tag: 'example-hero',
      child: SizedBox(
        width: size,
        height: size,
        child: const Material(
          color: Colors.teal,
          borderRadius: BorderRadius.all(Radius.circular(16)),
          child: Icon(Icons.bolt, color: Colors.white, size: 48),
        ),
      ),
    );
  }
}
