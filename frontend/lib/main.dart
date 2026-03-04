import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/repository_provider.dart';
import 'services/command_service.dart';

void main() {
  runApp(const StartItApp());
}

class StartItApp extends StatelessWidget {
  const StartItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => CommandService()),
        ChangeNotifierProxyProvider<CommandService, RepositoryProvider>(
          create: (context) => RepositoryProvider(
            commandService: Provider.of<CommandService>(context, listen: false),
          ),
          update: (context, commandService, previous) => previous!..updateCommandService(commandService),
        ),
      ],
      child: MaterialApp(
        title: 'StartIt',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
