import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/repository_provider.dart';
import '../services/command_service.dart';
import '../widgets/setup_steps.dart';
import '../widgets/prerequisites_widget.dart';
import '../widgets/terminal_output.dart';

class AnalysisScreen extends StatefulWidget {
  final String repositoryPath;
  
  const AnalysisScreen({
    super.key,
    required this.repositoryPath,
  });

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  @override
  void initState() {
    super.initState();
    // Start analysis when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<RepositoryProvider>(context, listen: false);
      provider.analyzeRepository(widget.repositoryPath);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RepositoryProvider>(context);
    final repository = provider.repository;
    final isLoading = provider.isLoading;
    final error = provider.error;
    
    // Use the terminal output from CommandService
    final commandService = provider.commandService;
    final isExecuting = commandService.isExecuting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Repository Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Back to Home',
            onPressed: () {
              provider.reset();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Repository info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.folder_open, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        repository?.url ?? 'Unknown Repository',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ]),
                    if (repository?.branch != null) ...[  
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.call_split, size: 18),
                        const SizedBox(width: 8),
                        Text('Branch: ${repository!.branch}'),
                      ]),
                    ],
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.folder_special, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Local path: ${repository?.localPath ?? ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ],
                ),
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
                    Row(children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Analysis Error',
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
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      error,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Main content area
            Expanded(
              child: repository == null || isLoading || repository.isAnalyzed != true
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Analyzing repository...'),
                        ],
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left panel: Setup steps and prerequisites
                        Expanded(
                          flex: 3,
                          child: Card(
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    repository.description,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Prerequisites',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  PrerequisitesWidget(
                                    prerequisites: repository.prerequisites,
                                    onInstall: (prerequisite) {
                                      provider.installPrerequisite(prerequisite);
                                    },
                                    isLoading: isLoading,
                                    onRecheckPrerequisites: () {
                                      provider.checkPrerequisites();
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Setup Steps',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: SetupSteps(
                                      steps: repository.setupSteps,
                                      onStepSelected: (step) {
                                        print('Step selected: $step');
                                        provider.executeStep(step);
                                      },
                                      isLoading: isLoading,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Right panel: Terminal output
                        Expanded(
                          flex: 2,
                          child: Consumer<CommandService>(
                            builder: (context, commandService, child) {
                              return TerminalOutput(
                                output: commandService.terminalOutput,
                                isRunning: commandService.isExecuting,
                                onClear: () => commandService.clearOutput(),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
            
            // Bottom action buttons
            if (repository != null && repository.isAnalyzed && !isLoading) ...[  
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Execute all setup commands button
                  if (provider.commands.isNotEmpty)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Run Setup Commands'),
                      onPressed: isExecuting ? null : () {
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
          ],
        ),
      ),
    );
  }
}
