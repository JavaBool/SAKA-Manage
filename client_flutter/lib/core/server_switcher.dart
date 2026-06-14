import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:client_flutter/core/providers.dart';
import 'package:client_flutter/core/theme.dart';

class ServerSwitcherWidget extends ConsumerWidget {
  const ServerSwitcherWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeUrl = ref.watch(backendUrlProvider);
    final notifier = ref.read(backendUrlProvider.notifier);

    final isHf = activeUrl == BackendUrlNotifier.huggingFaceUrl;
    final serverName = isHf ? "HF (Fast)" : "Render (Backup)";
    final serverColor = isHf ? AppTheme.success : AppTheme.warning;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: PopupMenuButton<String>(
        tooltip: "Change server",
        offset: const Offset(0, -90),
        onSelected: (url) async {
          if (url != activeUrl) {
            await notifier.setUrl(url);
            if (context.mounted) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Switched to ${url == BackendUrlNotifier.huggingFaceUrl ? 'Hugging Face' : 'Render'} server",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                  backgroundColor: AppTheme.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: BackendUrlNotifier.huggingFaceUrl,
            child: Row(
              children: [
                Icon(Icons.bolt, color: AppTheme.success, size: 18),
                SizedBox(width: 8),
                Text("Hugging Face (Fast)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: BackendUrlNotifier.renderUrl,
            child: Row(
              children: [
                Icon(Icons.cloud_queue, color: AppTheme.warning, size: 18),
                SizedBox(width: 8),
                Text("Render.com (Backup)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: serverColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                serverName,
                style: const TextStyle(
                  color: AppTheme.textMain,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Icon(Icons.arrow_drop_up, color: AppTheme.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
