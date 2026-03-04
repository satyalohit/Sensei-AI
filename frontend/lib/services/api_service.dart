import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;

  ApiService({this.baseUrl = 'http://localhost:8080/api'});

  Future<Map<String, dynamic>> cloneRepository(String url, {String? branch, String? destPath}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/repository/clone'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'url': url,
          if (branch != null) 'branch': branch,
          if (destPath != null) 'destPath': destPath,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode} - ${response.body}',
        };
      }
    } on SocketException {
      return {
        'success': false,
        'error': 'Cannot connect to server. Please ensure the backend is running.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to clone repository: $e',
      };
    }
  }

  Future<Map<String, dynamic>> analyzeRepository(String repoPath) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/repository/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'repoPath': repoPath,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode} - ${response.body}',
        };
      }
    } on SocketException {
      return {
        'success': false,
        'error': 'Cannot connect to server. Please ensure the backend is running.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to analyze repository: $e',
      };
    }
  }

  /// Execute a command in a repository context
  Future<String?> executeCommandInRepo(String command, String repoPath) async {
    try {
      final url = '$baseUrl/command'; // Use the command endpoint which works
      print('Executing command in repository: $command (path: $repoPath)');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'command': command,
          'repoPath': repoPath,
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode != 200) {
        print('Error: Received status code ${response.statusCode}');
        throw Exception('Server returned status code ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        print('Command executed successfully: $command');
        return data['data']['output'] as String;
      } else {
        final errorMsg = data['error'] ?? 'Unknown error';
        print('Command execution failed: $errorMsg');
        
        // Provide more user-friendly error messages for common GitHub issues
        if (errorMsg.contains('authorization required') || errorMsg.contains('Authentication failed')) {
          throw Exception('GitHub authentication required. Use a public repository or configure GitHub credentials.');
        }
        
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('Error executing command: $e');
      throw Exception('Failed to execute command: $e');
    }
  }

  /// Execute a command with arguments in a specified directory
  Future<Map<String, dynamic>> executeCommand(
    String command, {
    List<String>? args,
    String? directory,
  }) async {
    try {
      final url = '$baseUrl/execute-command'; // Updated to use the correct endpoint
      print('Executing command: $command with args: $args in directory: $directory');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'command': command,
          'repoPath': directory ?? '', // Updated to use repoPath instead of directory
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      final data = jsonDecode(response.body);
      if (response.statusCode != 200) {
        print('Command failed with status ${response.statusCode}: ${data['error']}');
        return {
          'success': false,
          'error': data['error'] ?? 'Unknown error',
        };
      }

      print('Command execution response: ${data['success']}');
      return data;
    } catch (e) {
      print('Exception during command execution: $e');
      return {
        'success': false,
        'error': 'Failed to execute command: $e',
      };
    }
  }

  /// Execute a command in the background with arguments in a specified directory
  Future<Map<String, dynamic>> executeCommandInBackground(
    String command, {
    List<String>? args,
    String? directory,
  }) async {
    try {
      final url = '$baseUrl/background-command';
      print('Executing background command: $command with args: $args in directory: $directory');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'command': command,
          'repoPath': directory ?? '',
        }),
      );

      print('Background command response status: ${response.statusCode}');
      print('Background command response body: ${response.body}');
      
      final data = jsonDecode(response.body);
      if (response.statusCode != 200) {
        print('Background command failed with status ${response.statusCode}: ${data['error']}');
        return {
          'success': false,
          'error': data['error'] ?? 'Unknown error',
        };
      }

      // Extract commandId from the data field in the response
      final commandId = data['data']['commandId'];
      print('Background command started with ID: $commandId');
      
      return {
        'success': true,
        'commandId': commandId,
      };
    } catch (e) {
      print('Exception during background command execution: $e');
      return {
        'success': false,
        'error': 'Failed to execute background command: $e',
      };
    }
  }

  /// Get the status of a background command
  Future<Map<String, dynamic>> getCommandStatus(String commandId) async {
    try {
      final url = '$baseUrl/command-status/$commandId';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      print('Command status response: ${response.statusCode}');
      
      final responseData = jsonDecode(response.body);
      if (response.statusCode != 200) {
        print('Failed to get command status: ${responseData['error']}');
        return {
          'success': false,
          'error': responseData['error'] ?? 'Unknown error',
        };
      }

      // Make sure we return the whole response including the data field
      return responseData;
    } catch (e) {
      print('Exception getting command status: $e');
      return {
        'success': false,
        'error': 'Failed to get command status: $e',
      };
    }
  }

  Future<Map<String, dynamic>> troubleshoot(
    String error,
    String repoPath, {
    String? context,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/troubleshoot'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'error': error,
          'repoPath': repoPath,
          if (context != null) 'context': context,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode} - ${response.body}',
        };
      }
    } on SocketException {
      return {
        'success': false,
        'error': 'Cannot connect to server. Please ensure the backend is running.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to get troubleshooting assistance: $e',
      };
    }
  }
}
