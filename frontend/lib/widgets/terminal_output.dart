import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TerminalOutput extends StatefulWidget {
  final List<String> output;
  final bool isRunning;
  final Function? onClear;

  const TerminalOutput({
    Key? key,
    required this.output,
    this.isRunning = false,
    this.onClear,
  }) : super(key: key);

  @override
  State<TerminalOutput> createState() => _TerminalOutputState();
}

class _TerminalOutputState extends State<TerminalOutput> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void didUpdateWidget(TerminalOutput oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.output.length != oldWidget.output.length && _autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _copyOutputToClipboard(BuildContext context) {
    final text = widget.output.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Terminal output copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Terminal header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF333333),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Terminal Output',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${widget.output.length} lines',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(width: 8),
                if (widget.onClear != null)
                  IconButton(
                    icon: const Icon(Icons.clear_all, color: Colors.white, size: 16),
                    onPressed: () => widget.onClear!(),
                    tooltip: 'Clear terminal',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                IconButton(
                  icon: const Icon(Icons.content_copy, color: Colors.white, size: 16),
                  onPressed: () => _copyOutputToClipboard(context),
                  tooltip: 'Copy to clipboard',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
                if (widget.isRunning)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
              ],
            ),
          ),
          // Terminal content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8.0),
              child: widget.output.isEmpty
                  ? const Center(
                      child: Text(
                        'No output yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.output.map((line) {
                          // Determine if the line is an error, command, or regular output
                          Color textColor = Colors.white;
                          if (line.startsWith('Error:')) {
                            textColor = Colors.red;
                          } else if (line.startsWith('Warning:')) {
                            textColor = Colors.orange;
                          } else if (line.startsWith('\$')) {
                            textColor = Colors.green;
                          } else if (line.startsWith('Success:')) {
                            textColor = Colors.lightGreen;
                          }
                          
                          return Text(
                            line,
                            style: TextStyle(
                              color: textColor,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
