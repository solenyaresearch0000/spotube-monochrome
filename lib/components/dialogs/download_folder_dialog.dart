import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotube/collections/spotube_icons.dart';
import 'package:spotube/extensions/context.dart';
import 'package:spotube/provider/user_preferences/user_preferences_provider.dart';
import 'package:spotube/utils/platform.dart';

const _kLastDownloadFolderKey = "spotube.last_download_folder";

/// Ask the user which folder to download into, then return the chosen absolute
/// path (or null if cancelled). Choices are the global download location plus
/// every registered local-library folder; picking "New folder…" creates one
/// and registers it as a local-library location so it surfaces as its own
/// Library section. The last-used folder is remembered and shown first.
Future<String?> showDownloadFolderPicker(
  BuildContext context,
  Ref ref,
) async {
  final prefs = ref.read(userPreferencesProvider);
  final prefsNotifier = ref.read(userPreferencesProvider.notifier);
  final sp = await SharedPreferences.getInstance();
  final lastUsed = sp.getString(_kLastDownloadFolderKey);

  // Ordered, de-duplicated folder list with the last-used one floated to top.
  final folders = <String>{
    if (prefs.downloadLocation.isNotEmpty) prefs.downloadLocation,
    ...prefs.localLibraryLocation,
  }.toList();
  if (lastUsed != null && folders.contains(lastUsed)) {
    folders
      ..remove(lastUsed)
      ..insert(0, lastUsed);
  }

  if (!context.mounted) return null;

  final chosen = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(context.l10n.download),
        content: SizedBox(
          width: 400,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final dir in folders)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Button.ghost(
                    alignment: Alignment.centerLeft,
                    leading: Icon(
                      dir == prefs.downloadLocation
                          ? SpotubeIcons.download
                          : SpotubeIcons.folder,
                    ),
                    onPressed: () => Navigator.pop(context, dir),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            dir == prefs.downloadLocation
                                ? context.l10n.download_location
                                : p.basename(dir),
                          ),
                        ),
                        if (dir == lastUsed)
                          const Icon(SpotubeIcons.done, size: 16),
                      ],
                    ),
                  ),
                ),
              const Divider(),
              Button.ghost(
                alignment: Alignment.centerLeft,
                leading: const Icon(SpotubeIcons.folderAdd),
                onPressed: () async {
                  String? newDir;
                  if (kIsMobile || kIsMacOS) {
                    newDir = await FilePicker.platform.getDirectoryPath(
                      initialDirectory: prefs.downloadLocation,
                    );
                  } else {
                    newDir = await getDirectoryPath(
                      initialDirectory: prefs.downloadLocation,
                    );
                  }
                  if (newDir == null) return;
                  // Register the new folder as a local-library location so it
                  // shows up as its own section, then return it.
                  if (!prefs.localLibraryLocation.contains(newDir) &&
                      newDir != prefs.downloadLocation) {
                    prefsNotifier.setLocalLibraryLocation(
                      [...prefs.localLibraryLocation, newDir],
                    );
                  }
                  if (context.mounted) Navigator.pop(context, newDir);
                },
                child: Text(context.l10n.add_library_location),
              ),
            ],
          ),
        ),
        actions: [
          Button.outline(
            onPressed: () => Navigator.pop(context, null),
            child: Text(context.l10n.cancel),
          ),
        ],
      );
    },
  );

  if (chosen != null) {
    await sp.setString(_kLastDownloadFolderKey, chosen);
  }
  return chosen;
}
