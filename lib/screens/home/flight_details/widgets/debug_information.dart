import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget para mostrar información de depuración cuando el modo desarrollador está activo
class DebugInformation extends StatelessWidget {
  final String documentId;
  final VoidCallback onShowAdditionalInfo;

  const DebugInformation({
    required this.documentId,
    required this.onShowAdditionalInfo,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bug_report, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Debug Information',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Document ID:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        tooltip: 'Copy to clipboard',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: documentId));
                          // Show a snackbar to indicate the copy was successful
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Document ID copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    documentId,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onShowAdditionalInfo,
              icon: const Icon(Icons.info_outline),
              label: const Text('Show Additional Information'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
