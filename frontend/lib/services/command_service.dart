import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/command_result.dart';
import 'api_service.dart';

/// Mixin to help with proper disposal of resources
mixin DisposableMixin on ChangeNotifier {
  bool _disposed = false;
  
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
  
  /// Check if object has been disposed
  bool get isDisposed => _disposed;
}

/// Service for managing and executing commands 
class CommandService extends ChangeNotifier with DisposableMixin {
  final ApiService _apiService;
  
  List<CommandResult> _commandResults = [];
  List<String> _terminalOutput = [];
  bool _isExecuting = false;
  String? _error;

  // Store background command IDs
  final Map<String, String> _backgroundCommands = {};
  Timer? _statusPollingTimer;

  // Maps to keep track of output lines already displayed
  final Map<String, Set<String>> _processedOutputLines = {};
  final Map<String, Set<String>> _processedErrorLines = {};
  final Set<String> _completedCommands = {};

  CommandService({ApiService? apiService}) 
      : _apiService = apiService ?? ApiService();

  List<CommandResult> get commandResults => _commandResults;
  List<String> get terminalOutput => _terminalOutput;
  bool get isExecuting => _isExecuting;
  String? get error => _error;

  /// Clear all terminal output
  void clearOutput() {
    _terminalOutput = [];
    notifyListeners();
  }

  /// Public method to add a line to the terminal output
  void addOutput(String line) {
    _addOutput(line);
  }

  /// Internal method to add a line to the terminal output
  void _addOutput(String line) {
    _terminalOutput.add(line);
    notifyListeners();
  }

  /// Execute a single command
  Future<CommandResult?> executeCommand({
    required String command,
    List<String>? args,
    String? directory,
  }) async {
    _isExecuting = true;
    _error = null;
    
    // Log the command execution to the terminal
    addOutput('\$ ${command} ${args?.join(' ') ?? ''}');
    addOutput('Executing command in ${directory ?? 'current directory'}...');
    
    notifyListeners();

    try {
      final response = await _apiService.executeCommand(
        command,
        args: args,
        directory: directory,
      );
      
      // Get the command result regardless of success
      if (response.containsKey('data')) {
        final commandResult = CommandResult.fromJson(response['data']);
        
        // Add the command result to the list
        _commandResults.add(commandResult);
        
        // Add command output to terminal
        addOutput('Command exited with code: ${commandResult.exitCode}');
        
        // Display command output
        if (commandResult.output.isNotEmpty) {
          // Split multi-line output
          final outputLines = commandResult.output.split('\n');
          for (final line in outputLines) {
            if (line.trim().isNotEmpty) {
              addOutput(line);
            }
          }
        }
        
        // Display error output if present
        if (commandResult.error != null && commandResult.error!.isNotEmpty) {
          addOutput('Error output: ${commandResult.error}');
        }
        
        addOutput('Command completed in ${commandResult.duration}');
        
        // Check if the command was actually successful (execution successful + exit code 0)
        if (response['success'] == true) {
          _isExecuting = false;
          notifyListeners();
          return commandResult;
        } else {
          // Command ran but failed with non-zero exit code
          _error = response['error'] ?? 'Command failed with non-zero exit code';
          addOutput('Command failed: ${_error}');
          
          // Suggest user how to troubleshoot
          addOutput('Tip: Check if you are in the correct directory or if prerequisites are installed.');
          
          _isExecuting = false;
          notifyListeners();
          return commandResult; // Still return the result for inspection
        }
      } else {
        // No data in response
        _error = response['error'] ?? 'Unknown error (no command data returned)';
        addOutput('Error: ${_error}');
        _isExecuting = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _error = e.toString();
      addOutput('Exception: ${_error}');
      _isExecuting = false;
      notifyListeners();
      return null;
    }
  }

  /// Execute a command in the repository context
  Future<String?> executeCommandInRepo(String command, String directory) async {
    try {
      print('CommandService: Executing command in repo: $command in directory: $directory');
      addOutput('\$ $command');
      
      if (directory == null) {
        throw Exception('Directory cannot be null');
      }
      
      final result = await _apiService.executeCommandInRepo(command, directory);
      
      if (result != null) {
        addOutput(result);
      }
      
      return result;
    } catch (e) {
      addOutput('Exception: $e');
      return null;
    }
  }
  
  /// Add a log message to the terminal
  void addLogMessage(String message, {bool isError = false, bool isWarning = false, bool isCommand = false, bool isSuccess = false}) {
    if (isError) {
      addOutput('Error: $message');
    } else if (isWarning) {
      addOutput('Warning: $message');
    } else if (isCommand) {
      addOutput('\$ $message');
    } else if (isSuccess) {
      addOutput('Success: $message');
    } else {
      addOutput(message);
    }
  }
  
  /// Execute multiple commands sequentially
  Future<List<CommandResult>> executeCommands({
    required List<String> commands,
    String? directory,
    bool stopOnError = false,
  }) async {
    List<CommandResult> results = [];
    
    for (final command in commands) {
      if (command.trim().isEmpty) continue;
      
      final result = await executeCommand(
        command: command,
        directory: directory,
      );
      
      if (result != null) {
        results.add(result);
        
        // Stop if there's an error and stopOnError is true
        if (stopOnError && result.exitCode != 0) {
          break;
        }
      } else {
        if (stopOnError) break;
      }
    }
    
    return results;
  }

  /// Execute a command in repo with background processing
  Future<Map<String, dynamic>?> executeCommandInBackgroundRepo(
    String command,
    String repoPath,
  ) async {
    addLogMessage("Starting: $command", isCommand: true);
    
    try {
      final result = await _apiService.executeCommandInBackground(
        command,
        directory: repoPath,
      );
      
      if (result['success'] == true && result['commandId'] != null) {
        final commandId = result['commandId'];
        trackBackgroundCommand(command, commandId);
        
        return result;
      } else {
        addLogMessage(
          "Error starting command: ${result['error'] ?? 'Unknown error'}", 
          isError: true,
        );
        return null;
      }
    } catch (e) {
      addLogMessage("Exception running command: $e", isError: true);
      return null;
    }
  }

  /// Add a command to track as a background command
  void trackBackgroundCommand(String command, String commandId) {
    _backgroundCommands[command] = commandId;
    
    // Initialize tracking sets for this command
    _processedOutputLines.putIfAbsent(command, () => {});
    _processedErrorLines.putIfAbsent(command, () => {});
    
    // Start polling if this is the first background command
    if (_backgroundCommands.length == 1) {
      _startStatusPolling();
    }
  }

  /// Start polling for command status updates
  void _startStatusPolling() {
    _statusPollingTimer?.cancel();
    
    // Poll more frequently (every second) to get real-time updates
    _statusPollingTimer = Timer.periodic(Duration(seconds: 1), (_) {
      _pollCommandStatus();
    });
  }

  /// Poll for status of all background commands
  Future<void> _pollCommandStatus() async {
    if (_backgroundCommands.isEmpty) {
      _statusPollingTimer?.cancel();
      _statusPollingTimer = null;
      return;
    }
    
    // poll the status of each command
    _backgroundCommands.forEach((command, commandId) async {
      try {
        // Get the status from server
        final status = await _apiService.getCommandStatus(commandId);
        
        if (status['success'] == true) {
          // Process command result
          _processCommandStatus(command, status);
        }
      } catch (e) {
        print('Error polling command status: $e');
      }
    });
  }

  /// Process a command status update
  void _processCommandStatus(String command, Map<String, dynamic> status) {
    if (status['success'] != true || status['data'] == null) {
      addLogMessage(
        "Failed to get command status: ${status['error'] ?? 'Unknown error'}", 
        isError: true
      );
      // Remove from tracking to avoid endless errors
      _backgroundCommands.remove(command);
      return;
    }
    
    // Extract data from the response
    final data = status['data'] as Map<String, dynamic>;
    final cmdStatus = data['status'];
    final isCompleted = data['isCompleted'] == true;
    
    // Process real-time output if available
    if (data['currentOutput'] != null && data['currentOutput'].toString().isNotEmpty) {
      final outputLines = data['currentOutput'].toString().split('\n');
      for (final line in outputLines) {
        if (line.trim().isNotEmpty && !_processedOutputLines[command]!.contains(line)) {
          _processedOutputLines[command]!.add(line);
          addOutput(line);
        }
      }
    }

    // Process error output if available
    if (data['currentError'] != null && data['currentError'].toString().isNotEmpty) {
      final errorLines = data['currentError'].toString().split('\n');
      for (final line in errorLines) {
        if (line.trim().isNotEmpty && !_processedErrorLines[command]!.contains(line)) {
          _processedErrorLines[command]!.add(line);
          addLogMessage(line, isError: true);
        }
      }
    }

    // Handle completed commands
    if (isCompleted && !_completedCommands.contains(command)) {
      _completedCommands.add(command);
      
      // Add completion message
      if (data['result'] != null) {
        final result = data['result'] as Map<String, dynamic>;
        final exitCode = result['exitCode'] as int? ?? -1;
        
        // Log completion with exit code
        addLogMessage(
          'Command completed with exit code: $exitCode', 
          isSuccess: exitCode == 0,
          isError: exitCode != 0
        );
      }
      
      // Remove from active tracking
      _backgroundCommands.remove(command);
    }
  }

  /// Clean up resources
  @override
  void dispose() {
    _statusPollingTimer?.cancel();
    _statusPollingTimer = null;
    super.dispose();
  }
}
