import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/repository.dart';
import '../services/command_service.dart';
import '../services/repository_provider.dart';

class PrerequisitesWidget extends StatelessWidget {
  final List<Prerequisite> prerequisites;
  final Function(Prerequisite) onInstall;
  final bool isLoading;
  final VoidCallback onRecheckPrerequisites;

  const PrerequisitesWidget({
    Key? key,
    required this.prerequisites,
    required this.onInstall,
    required this.isLoading,
    required this.onRecheckPrerequisites,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RepositoryProvider>(context);
    // Count installed prerequisites
    final installedCount = prerequisites.where((p) => p.isInstalled == true).length;
    final allInstalled = installedCount == prerequisites.length;

    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Prerequisites',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  prerequisites.isEmpty 
                    ? '0/0 installed'
                    : '$installedCount/${prerequisites.length} installed',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Warning banner
          if (prerequisites.isNotEmpty && !allInstalled)
            Container(
              color: Colors.amber.shade50,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'All prerequisites must be installed before proceeding.',
                      style: TextStyle(color: Colors.orange.shade900, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          
          // Main content
          if (prerequisites.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 24,
                    color: Colors.blue.shade300,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No prerequisites detected',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: prerequisites.length,
                itemBuilder: (context, index) {
                  final prerequisite = prerequisites[index];
                  final isInstalled = prerequisite.isInstalled == true;
                  
                  return ListTile(
                    dense: true,
                    leading: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isInstalled ? Colors.green : Colors.grey.shade300,
                      ),
                      child: Icon(
                        isInstalled ? Icons.check : Icons.close,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                    title: Text(
                      prerequisite.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: !isInstalled && prerequisite.installCommand != null && prerequisite.installCommand!.isNotEmpty
                      ? Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Command: ${prerequisite.installCommand}',
                                style: const TextStyle(fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            OutlinedButton(
                              onPressed: isLoading ? null : () => onInstall(prerequisite),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Run',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Text(
                          isInstalled ? 'Installed' : 'Not installed',
                          style: TextStyle(
                            color: isInstalled ? Colors.green : Colors.red,
                            fontSize: 11,
                          ),
                        ),
                  );
                },
              ),
            ),
          
          // Footer
          if (prerequisites.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: onRecheckPrerequisites,
                    child: Text('Recheck Prerequisites'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
