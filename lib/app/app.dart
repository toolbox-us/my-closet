import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class MyClosetApp extends StatelessWidget {
  const MyClosetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'My Closet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: appRouter,
    );
  }
}
