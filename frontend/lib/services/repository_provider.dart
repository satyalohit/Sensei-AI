import 'package:flutter/foundation.dart';
import '../models/repository.dart';
import '../models/command_result.dart';
import 'api_service.dart';
import 'command_service.dart';

class RepositoryProvider with ChangeNotifier {
  final ApiService _apiService;
  final CommandService _commandService;
  
  Repository? _repository;
  bool _isLoading = false;
  String? _error;
  final List<CommandResult> _commandResults = [];
  String _description = '';
  List<String> _setupSteps = [];
  List<String> _commands = [];
  List<Prerequisite> _prerequisites = [];

  RepositoryProvider({
    ApiService? apiService,
    CommandService? commandService,
  }) 
      : _apiService = apiService ?? ApiService(),
        _commandService = commandService ?? CommandService();

  Repository? get repository => _repository;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<CommandResult> get commandResults => _commandResults;
  String get description => _description;
  List<String> get setupSteps => _setupSteps;
  List<String> get commands => _commands;
  List<Prerequisite> get prerequisites => _prerequisites;
  CommandService get commandService => _commandService;
  
  Future<void> cloneRepository(String url, {String? branch, String? destPath}) async {
    _isLoading = true;
    _error = null;
    
    // Clear any previous terminal output when starting a new clone
    _commandService.clearOutput();
    
    notifyListeners();

    final response = await _apiService.cloneRepository(url, branch: branch, destPath: destPath);
    
    if (response['success'] == true) {
      _repository = Repository(
        url: url,
        branch: branch,
        localPath: response['data']['localPath'],
      );
    } else {
      _error = response['error'];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> analyzeRepository([String? path]) async {
    if (path != null && path.isNotEmpty) {
      // If a path is provided, set the repository local path
      if (_repository == null) {
        _repository = Repository(
          url: "Local Repository",
          localPath: path,
        );
      } else {
        _repository = _repository!.copyWith(localPath: path);
      }
    }
    
    if (_repository == null || _repository!.localPath == null) {
      _error = 'No repository to analyze';
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      
      // Clear previous terminal output when starting analysis
      _commandService.clearOutput();
      _commandService.addOutput("Analyzing repository: ${_repository!.url}\n");
      _commandService.addOutput("This may take a few moments...");
      
      notifyListeners();

      await Future.delayed(Duration(milliseconds: 100));
      notifyListeners();

      // Call the API to analyze the repository
      final response = await _apiService.analyzeRepository(_repository!.localPath!);
      
      if (response['success'] == true) {
        final data = response['data'];
        
        _description = data['description'] ?? '';
        _setupSteps = List<String>.from(data['setupSteps'] ?? []);
        _commands = List<String>.from(data['commands'] ?? []);
        
        // Parse prerequisites from the API response
        if (data['prerequisites'] != null) {
          _prerequisites = (data['prerequisites'] as List)
              .map((item) => Prerequisite(
                    name: item['name'],
                    description: item['description'],
                    installCommand: item['installCommand'],
                  ))
              .toList();
          
          // Check which prerequisites are installed
          await checkPrerequisites();
        } else {
          _prerequisites = [];
        }
        
        // Update the repository object with the setup steps and prerequisites
        _repository = _repository!.copyWith(
          setupSteps: _setupSteps,
          prerequisites: _prerequisites,
          isAnalyzed: true,
        );
        
        _isLoading = false;
        notifyListeners();
      } else {
        throw Exception('Invalid response from server');
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> checkPrerequisites() async {
    for (int i = 0; i < _prerequisites.length; i++) {
      final prerequisite = _prerequisites[i];
      bool isInstalled = await _checkIfSoftwareInstalled(prerequisite.name);
      
      _prerequisites[i] = prerequisite.copyWith(isInstalled: isInstalled);
    }
    
    // Update the repository with the checked prerequisites
    if (_repository != null) {
      _repository = _repository!.copyWith(prerequisites: _prerequisites);
    }
    
    notifyListeners();
  }

  Future<bool> _checkIfSoftwareInstalled(String name) async {
    try {
      final String command = _getVersionCheckCommand(name);
      if (command.isEmpty) return false;
      
      final output = await _commandService.executeCommandInRepo(command, _repository!.localPath!);
      return output != null && (output.toLowerCase().contains('version') || !output.toLowerCase().contains('not found'));
    } catch (e) {
      return false;
    }
  }

  String _getVersionCheckCommand(String name) {
    final lowercaseName = name.toLowerCase();
    
    if (lowercaseName.contains('node')) return 'node --version';
    if (lowercaseName.contains('npm')) return 'npm --version';
    if (lowercaseName.contains('docker')) return 'docker --version';
    if (lowercaseName.contains('postgres')) return 'psql --version';
    if (lowercaseName.contains('python')) return 'python --version';
    if (lowercaseName.contains('java')) return 'java --version';
    if (lowercaseName.contains('go')) return 'go version';
    if (lowercaseName.contains('rust') || lowercaseName.contains('cargo')) return 'rustc --version';
    if (lowercaseName.contains('mysql')) return 'mysql --version';
    if (lowercaseName.contains('mongo')) return 'mongo --version';
    
    return '';
  }

  Future<String> executeCommandInRepo(String command) async {
    if (_repository == null || _repository!.localPath == null) {
      throw Exception('No repository is selected');
    }
    
    try {
      final output = await _commandService.executeCommandInRepo(command, _repository!.localPath!);
      return output ?? '';
    } catch (e) {
      throw Exception('Command execution failed: $e');
    }
  }

  Future<CommandResult?> executeCommand(
    String command, {
    List<String>? args,
    String? directory,
  }) async {
    _isLoading = true;
    _error = null;
    
    // Clear any previous terminal output when starting a new command
    _commandService.clearOutput();
    
    notifyListeners();

    final commandResult = await _commandService.executeCommand(
      command: command,
      args: args,
      directory: directory ?? (_repository?.localPath),
    );
    
    if (commandResult != null) {
      _commandResults.add(commandResult);
      _isLoading = false;
      notifyListeners();
    } else {
      _error = 'Command execution failed';
      _isLoading = false;
      notifyListeners();
    }
    
    return commandResult;
  }

  // Execute a setup step from its description
  Future<void> executeStep(String step) async {
    // Skip steps related to cloning repositories
    if (step.toLowerCase().contains('git clone') || 
        step.toLowerCase().contains('clone the') || 
        step.toLowerCase().contains('clone this')) {
      _commandService.addLogMessage(
        "Skipping clone step as repository is already cloned.", 
        isWarning: true
      );
      return;
    }
    
    if (_repository != null && _repository!.localPath != null) {
      // Always treat the step as a command directly
      final command = step.trim();
      
      print('Using step as command: $command');
      _commandService.addLogMessage("Executing: $command", isCommand: true);
          
      // Use the background execution
      _commandService.executeCommandInBackgroundRepo(
        command,
        _repository!.localPath!,
      ).then((result) {
        if (result == null) {
          _commandService.addLogMessage(
            "Command execution failed to start", 
            isError: true
          );
        }
      }).catchError((error) {
        _commandService.addLogMessage(
          "Error: $error", 
          isError: true
        );
      });
      
      // Add a small delay to ensure UI updates
      await Future.delayed(Duration(milliseconds: 100));
    } else {
      print('Repository is not available');
      if (_repository == null) print('Repository is null');
      if (_repository?.localPath == null) print('Repository local path is null');
      
      _commandService.addLogMessage(
        "Repository is not available", 
        isError: true
      );
    }
  }

  // Execute all setup commands in order
  Future<void> executeSetupCommands() async {
    if (_repository == null || _repository!.localPath == null || _commands.isEmpty) {
      return;
    }
    
    _isLoading = true;
    notifyListeners();
    
    try {
      // Clear previous terminal output when starting setup commands
      _commandService.clearOutput();
      
      // Add information about running commands
      _commandService.addLogMessage("Starting execution of setup commands...");
      
      for (var command in _commands) {
        if (command.trim().isNotEmpty) {
          // Skip git clone commands
          if (command.toLowerCase().contains('git clone')) {
            _commandService.addLogMessage(
              "Skipping: $command (repository already cloned)",
              isWarning: true
            );
            continue;
          }
          
          _commandService.addLogMessage("Executing: $command", isCommand: true);
          
          // Use background execution
          await _commandService.executeCommandInBackgroundRepo(
            command, 
            _repository!.localPath!,
          );
          
          // Add a small delay to ensure UI updates between commands
          await Future.delayed(Duration(milliseconds: 300));
        }
      }
      
      _commandService.addLogMessage("All setup commands launched. Check terminal for results.");
    } catch (e) {
      _error = e.toString();
      _commandService.addLogMessage("Error running commands: $e", isError: true);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> getTroubleshooting(String error, {String? context}) async {
    if (_repository == null || _repository!.localPath == null) {
      _error = 'No repository context for troubleshooting';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.troubleshoot(
        error,
        _repository!.localPath!,
        context: context,
      );
      
      _isLoading = false;
      notifyListeners();
      
      if (response['success'] == true) {
        return response['data']['solution'];
      } else {
        _error = response['error'];
        return null;
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void reset() {
    _repository = null;
    _isLoading = false;
    _error = null;
    _commandResults.clear();
    _description = '';
    _setupSteps.clear();
    _commands.clear();
    _prerequisites.clear();
    _commandService.clearOutput();
    notifyListeners();
  }

  // Update the command service reference
  void updateCommandService(CommandService commandService) {
    // No implementation needed as we already have the commandService injected in the constructor
  }

  // Helper method to extract a command from a step description
  String? extractCommand(String step) {
    // Check if the step is a simple command (single word or common command)
    if (step.trim().split(' ').length <= 3 && 
        !step.contains(':') && 
        (step.trim().startsWith('npm') || 
         step.trim().startsWith('yarn') || 
         step.trim().startsWith('mvn') || 
         step.trim().startsWith('gradle') || 
         step.trim().startsWith('go ') || 
         step.trim().startsWith('python') || 
         step.trim().startsWith('pip') || 
         step.trim().contains('install') || 
         step.trim().contains('build') || 
         step.trim().contains('run'))) {
      return step.trim();
    }
    
    // Look for commands with $ prefix
    final commandRegex = RegExp(r'\$\s*([^\n]+)');
    final commandMatch = commandRegex.firstMatch(step);
    
    if (commandMatch != null && commandMatch.groupCount >= 1) {
      return commandMatch.group(1)?.trim();
    }
    
    // If the step is very short and doesn't contain any special characters,
    // assume it's a command itself
    if (step.trim().length < 30 && 
        !step.contains('.') && 
        !step.contains('?') && 
        !step.contains('!')) {
      return step.trim();
    }
    
    return step.trim(); // Just return the step itself as a fallback
  }

  // Install a prerequisite
  Future<void> installPrerequisite(Prerequisite prerequisite) async {
    print('Installing prerequisite: ${prerequisite.name}');
    print('Install command: ${prerequisite.installCommand}');
    print('Repository path: ${_repository?.localPath}');
    
    if (prerequisite.installCommand == null || prerequisite.installCommand!.isEmpty) {
      print('Cannot install: ${prerequisite.installCommand == null ? "command is null" : "command is empty"}');
      return;
    }
    
    if (_repository == null || _repository!.localPath == null) {
      print('Repository or localPath is null');
      _commandService.addLogMessage(
        "Error: Cannot install ${prerequisite.name} because repository is not available", 
        isError: true
      );
      return;
    }
    
    _commandService.addLogMessage(
      "Installing ${prerequisite.name}...", 
      isCommand: true
    );
    
    try {
      // Execute directly instead of using background execution
      await _commandService.executeCommandInRepo(
        prerequisite.installCommand!, 
        _repository!.localPath!,
      );
    } catch (e) {
      print('Error installing prerequisite: $e');
      _commandService.addLogMessage("Error installing ${prerequisite.name}: $e", isError: true);
    }
    
    // Recheck prerequisites after installation
    await checkPrerequisites();
  }
}
