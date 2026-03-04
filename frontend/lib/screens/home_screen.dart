import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/repository_input.dart';
import '../widgets/setup_steps.dart';
import '../widgets/prerequisites_widget.dart';
import '../widgets/terminal_output.dart';
import '../services/repository_provider.dart';
import '../models/repository.dart';
import '../models/command_result.dart';
import 'analysis_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RepositoryProvider>(context);
    final repository = provider.repository;
    final isLoading = provider.isLoading;
    final error = provider.error;
    
    // Use the terminal output from CommandService instead of directly from commandResults
    final terminalOutput = provider.commandService.terminalOutput;
    final isExecuting = provider.commandService.isExecuting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('StartIt'),
        actions: [
          if (repository != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset',
              onPressed: isLoading ? null : () => provider.reset(),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GitHub Repository Setup Assistant',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Error display
            if (error != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Error',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: provider.clearError,
                          color: Colors.red.shade700,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatErrorMessage(error),
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                    const SizedBox(height: 8),
                    if (error.contains('git clone failed') || error.contains('repository'))
                      Text(
                        'Tip: Make sure the repository URL is correct and publicly accessible.',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.red.shade400,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Repository input form
            RepositoryInput(
              onSubmit: (url, branch) {
                // Clone the repository and navigate to analysis if successful
                provider.cloneRepository(url, branch: branch).then((_) {
                  if (provider.repository != null && provider.error == null) {
                    // Navigate to analysis screen after successful clone
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AnalysisScreen(
                          repositoryPath: provider.repository!.localPath!,
                        ),
                      ),
                    );
                  }
                });
              },
              isLoading: isLoading,
            ),
            
            if (repository != null) ...[
              const SizedBox(height: 24),
              Text(
                'Repository: ${repository.url}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (repository.localPath != null)
                Text('Local path: ${repository.localPath}'),
              const SizedBox(height: 16),
              
              // Main content area with setup steps and terminal output
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          PrerequisitesWidget(
                            prerequisites: repository.prerequisites,
                            onInstall: (prerequisite) {
                              provider.installPrerequisite(prerequisite);
                            },
                            isLoading: isLoading,
                            onRecheckPrerequisites: () => provider.checkPrerequisites(),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            flex: 2,
                            child: SetupSteps(
                              steps: repository.setupSteps,
                              onStepSelected: (step) {
                                final command = extractCommand(step);
                                if (command != null) {
                                  provider.executeCommand(
                                    command,
                                    directory: repository.localPath,
                                  );
                                }
                              },
                              isLoading: isLoading,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: TerminalOutput(
                        output: terminalOutput,
                        isRunning: isExecuting,
                        onClear: () => provider.commandService.clearOutput(),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Bottom action buttons
              if (repository.isAnalyzed) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Execute all setup commands button
                    if (provider.commands.isNotEmpty)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Run Setup Commands'),
                        onPressed: isLoading || isExecuting ? null : () {
                          provider.executeSetupCommands();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ],
              
              // If not analyzed yet, show analyze button
              if (!repository.isAnalyzed && !isLoading && repository.localPath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: ElevatedButton(
                    onPressed: provider.analyzeRepository,
                    child: const Text('Analyze Repository'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper method to extract command from setup step
  String? extractCommand(String step) {
    // Extract command that comes after a colon or after words like "run", "execute"
    final colonRegex = RegExp(r':\s*(`?)(.*?)\1');
    final runRegex = RegExp(r'(?:run|execute)\s+(`?)([^`\n]+)\1', caseSensitive: false);
    
    final colonMatch = colonRegex.firstMatch(step);
    if (colonMatch != null && colonMatch.group(2) != null) {
      return colonMatch.group(2)!.trim();
    }
    
    final runMatch = runRegex.firstMatch(step);
    if (runMatch != null && runMatch.group(2) != null) {
      return runMatch.group(2)!.trim();
    }
    
    return step; // Return the whole step as a fallback
  }
  
  // Format error message for better readability
  String _formatErrorMessage(String error) {
    // Remove JSON artifacts
    String formatted = error
        .replaceAll(RegExp(r'\[".*?",\s*'), '')
        .replaceAll('"]', '')
        .replaceAll('\\"', '"');
    
    // Extract the most relevant part of Git errors
    if (formatted.contains('git clone failed')) {
      final match = RegExp(r'fatal:\s*(.+?)(?:\n|$)').firstMatch(formatted);
      if (match != null) {
        return 'Repository error: ${match.group(1)}';
      }
    }
    
    return formatted;
  }
}
