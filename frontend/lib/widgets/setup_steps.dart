import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class SetupSteps extends StatefulWidget {
  final List<String> steps;
  final Function(String) onStepSelected;
  final bool isLoading;

  const SetupSteps({
    super.key,
    required this.steps,
    required this.onStepSelected,
    this.isLoading = false,
  });

  @override
  State<SetupSteps> createState() => _SetupStepsState();
}

class _SetupStepsState extends State<SetupSteps> {
  int? _expandedStep;
  final List<bool> _completedSteps = [];

  @override
  void initState() {
    super.initState();
    _initializeCompletedSteps();
  }

  @override
  void didUpdateWidget(SetupSteps oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.steps.length != oldWidget.steps.length) {
      _initializeCompletedSteps();
    }
  }

  void _initializeCompletedSteps() {
    _completedSteps.clear();
    for (int i = 0; i < widget.steps.length; i++) {
      _completedSteps.add(false);
    }
  }

  void _toggleExpandedStep(int index) {
    setState(() {
      if (_expandedStep == index) {
        _expandedStep = null;
      } else {
        _expandedStep = index;
      }
    });
  }

  void _toggleCompletedStep(int index) {
    setState(() {
      _completedSteps[index] = !_completedSteps[index];
    });
  }

  // Extract command from a step description
  String? _extractCommand(String step) {
    // Look for commands with $ prefix
    final commandRegex = RegExp(r'\$\s*([^\n]+)');
    final commandMatch = commandRegex.firstMatch(step);
    
    if (commandMatch != null && commandMatch.groupCount >= 1) {
      return commandMatch.group(1)?.trim();
    }
    
    return step; // Return the whole step as a fallback
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) {
      return Card(
        elevation: 2,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 48,
                  color: Colors.blue.shade300,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No setup steps available yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter a repository URL to analyze setup instructions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Setup Steps',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_completedSteps.where((completed) => completed).length}/${widget.steps.length} completed',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: widget.steps.length,
              itemBuilder: (context, index) {
                final step = widget.steps[index];
                final isExpanded = _expandedStep == index;
                final isCompleted = _completedSteps[index];
                
                // Extract command if present (for display purposes)
                final commandMatch = step.trim().isNotEmpty;
                final hasCommand = commandMatch;
                
                return Column(
                  children: [
                    ListTile(
                      leading: Checkbox(
                        value: isCompleted,
                        onChanged: widget.isLoading 
                          ? null 
                          : (_) => _toggleCompletedStep(index),
                      ),
                      title: Text(
                        'Step ${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: isCompleted 
                            ? TextDecoration.lineThrough 
                            : null,
                        ),
                      ),
                      subtitle: Text(
                        step.length > 50 ? '${step.substring(0, 50)}...' : step,
                        style: TextStyle(
                          decoration: isCompleted 
                            ? TextDecoration.lineThrough 
                            : null,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              isExpanded 
                                ? Icons.keyboard_arrow_up 
                                : Icons.keyboard_arrow_down
                            ),
                            onPressed: () => _toggleExpandedStep(index),
                            tooltip: isExpanded ? 'Collapse' : 'Expand',
                          ),
                          IconButton(
                            icon: const Icon(Icons.play_arrow),
                            onPressed: widget.isLoading
                                ? null
                                : () {
                                    widget.onStepSelected(_extractCommand(step) ?? '');
                                    if (!isCompleted) {
                                      _toggleCompletedStep(index);
                                    }
                                  },
                            tooltip: 'Execute this step',
                          ),
                        ],
                      ),
                      onTap: () => _toggleExpandedStep(index),
                    ),
                    if (isExpanded)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
                              color: Colors.grey.shade50,
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: MarkdownBody(
                                  data: step,
                                  selectable: true,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (hasCommand) ...[
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.play_arrow, size: 16),
                                  label: const Text('Execute'),
                                  onPressed: widget.isLoading
                                      ? null
                                      : () {
                                          widget.onStepSelected(step);
                                          if (!isCompleted) {
                                            _toggleCompletedStep(index);
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    const Divider(height: 1),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
