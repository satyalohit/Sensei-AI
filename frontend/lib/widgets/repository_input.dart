import 'package:flutter/material.dart';

class RepositoryInput extends StatefulWidget {
  final Function(String, String) onSubmit;
  final bool isLoading;

  const RepositoryInput({
    super.key,
    required this.onSubmit,
    required this.isLoading,
  });

  @override
  State<RepositoryInput> createState() => _RepositoryInputState();
}

class _RepositoryInputState extends State<RepositoryInput> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _branchController = TextEditingController(text: 'main');
  bool _validURL = false;
  bool _showError = false;
  bool _showAdvanced = false;

  @override
  void dispose() {
    _urlController.dispose();
    _branchController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_validURL) {
      final url = _urlController.text;
      final branch = _branchController.text.isNotEmpty ? _branchController.text : 'main';
      widget.onSubmit(url, branch);
    } else {
      setState(() {
        _showError = true;
      });
    }
  }

  bool _validateURL(String url) {
    if (url.isEmpty) {
      return false;
    }

    // Accept standard GitHub URLs
    if (url.startsWith('https://github.com/') && url.split('/').length >= 3) {
      return true;
    }
    
    // Accept git@ style URLs
    if (url.startsWith('git@github.com:') && url.split(':').length == 2) {
      return true;
    }
    
    // Accept username/repo format
    if (!url.contains('://') && url.split('/').length == 2) {
      // Simple username/repo format
      return true;
    }
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _urlController,
          decoration: InputDecoration(
            labelText: 'Enter a GitHub repository URL',
            hintText: 'https://github.com/username/repository',
            prefixIcon: const Icon(Icons.link),
            suffixIcon: _urlController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _urlController.clear();
                      setState(() {
                        _validURL = false;
                      });
                    },
                  )
                : null,
            border: const OutlineInputBorder(),
            errorText: _showError ? 'Please enter a valid GitHub repository URL' : null,
            helperText: 'Enter a GitHub repository URL or username/repository format',
            helperStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          onChanged: (value) {
            setState(() {
              _validURL = _validateURL(value);
              _showError = false;
            });
          },
          enabled: !widget.isLoading,
        ),
        const SizedBox(height: 8),
        
        // Advanced features toggle
        GestureDetector(
          onTap: () {
            setState(() {
              _showAdvanced = !_showAdvanced;
            });
          },
          child: Row(
            children: [
              Icon(
                _showAdvanced ? Icons.arrow_drop_down : Icons.arrow_right,
                size: 20,
                color: Colors.blue,
              ),
              const Text(
                'Advanced Options',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        
        if (_showAdvanced) ...[
          const SizedBox(height: 8),
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Branch Selection
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Branch Selection:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      
                      // Branch dropdown
                      Row(
                        children: [
                          const Text('Select branch: '),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _branchController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: widget.isLoading ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
          ),
          child: widget.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Text('Analyze'),
        ),
      ],
    );
  }
}
