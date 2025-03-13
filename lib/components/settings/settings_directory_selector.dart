import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saber/components/theming/adaptive_alert_dialog.dart';
import 'package:saber/components/theming/font_fallbacks.dart';
import 'package:saber/data/file_manager/file_manager.dart';
import 'package:saber/data/nextcloud/saber_syncer.dart';
import 'package:saber/data/prefs.dart';
import 'package:saber/i18n/strings.g.dart';
import 'package:saber/main_common.dart';

class SettingsDirectorySelector extends StatelessWidget {
  const SettingsDirectorySelector({
    super.key,
    required this.title,
    required this.icon,
    this.afterChange,
  });

  final String title;
  final IconData icon;
  final ValueChanged<Color?>? afterChange;

  void onPressed(context) async {
    final oldDir = Directory(FileManager.documentsDirectory);
    final oldDirIsEmpty =
        oldDir.existsSync() ? oldDir.listSync().isEmpty : true;
    await showAdaptiveDialog(
      context: context,
      builder: (context) => DirectorySelector(
        title: title,
        initialDirectory: FileManager.documentsDirectory,
        mustBeEmpty: !oldDirIsEmpty,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onPressed(context),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        leading: AnimatedSwitcher(
          duration: const Duration(milliseconds: 100),
          child: Icon(icon, key: ValueKey(icon)),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontStyle:
                Prefs.customDataDir.value != Prefs.customDataDir.defaultValue
                    ? FontStyle.italic
                    : null,
          ),
        ),
        subtitle: ValueListenableBuilder(
          valueListenable: Prefs.customDataDir,
          builder: (context, _, __) => Text(
            FileManager.documentsDirectory,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ),
    );
  }
}

class DirectorySelector extends StatefulWidget {
  const DirectorySelector({
    super.key,
    required this.title,
    required this.initialDirectory,
    this.mustBeEmpty = true,
    this.mustBeDoneSyncing = true,
  });

  final String title;
  final String initialDirectory;
  final bool mustBeEmpty;
  final bool mustBeDoneSyncing;

  @override
  State<DirectorySelector> createState() => _DirectorySelectorState();
}

class _DirectorySelectorState extends State<DirectorySelector> {
  late String _directory = widget.initialDirectory;
  late bool _isEmpty = true;

  Future<void> _pickDir() async {
    final directory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: widget.title,
      initialDirectory: _directory,
    );

    if (directory == null) return;
    if (directory == _directory) return;

    final dir = Directory(directory);
    _directory = directory;
    _isEmpty = dir.existsSync() ? dir.listSync().isEmpty : true;

    if (!mounted) return;

    setState(() {});
  }

  Future<void> _pickDefaultDir() async {
    final directory = await FileManager.getDefaultDocumentsDirectory();

    final dir = Directory(directory);
    _directory = directory;
    _isEmpty = (dir.existsSync() ? dir.listSync().isEmpty : true) || true;

    if (!mounted) return;
    setState(() {});
  }

  Future<void> requestStoragePermission() async {
    final status = await Permission.manageExternalStorage.request();
    if (status.isGranted) {
      // Permission is granted, no need to do anything
    } else if (status.isDenied) {
      // Permission is denied
      openAppSettings(); // Open app settings to manually grant permission
    } else if (status.isPermanentlyDenied) {
      // Permission is permanently denied
      openAppSettings(); // Open app settings to manually grant permission
    }
  }

  void _onConfirm() {
    Prefs.customDataDir.value = _directory;
    context.pop();
    if (Platform.isAndroid && !_directory.startsWith('/data/user/')) {
      showDialog(
          context: context,
          builder: (context) => AdaptiveAlertDialog(
                  title: Text(t.settings.customDataDir.grantPermission),
                  content:
                      Text(t.settings.customDataDir.grantPermissionExplenation),
                  actions: [
                    CupertinoDialogAction(
                      onPressed: () => context.pop(),
                      child: Text(t.settings.customDataDir.cancel),
                    ),
                    CupertinoDialogAction(
                      isDefaultAction: true,
                      onPressed: () {
                        context.pop();
                        requestStoragePermission();
                      },
                      child: Text(t.settings.customDataDir.yes),
                    ),
                  ]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final emptyError = widget.mustBeEmpty && !_isEmpty;
    final syncingError = widget.mustBeDoneSyncing &&
        (syncer.uploader.numPending > 0 || syncer.downloader.numPending > 0);
    final anyErrors = emptyError || syncingError;

    return AdaptiveAlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _directory,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'FiraMono',
                    fontFamilyFallback: saberMonoFontFallbacks,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.folder),
                onPressed: _pickDir,
              ),
              if (Prefs.customDataDir.value != null)
                IconButton(
                  icon: const Icon(Icons.undo),
                  onPressed: _pickDefaultDir,
                ),
            ],
          ),
          if (emptyError)
            Text(t.settings.customDataDir.mustBeEmpty,
                style: TextStyle(color: colorScheme.error)),
          if (syncingError)
            Text(t.settings.customDataDir.mustBeDoneSyncing,
                style: TextStyle(color: colorScheme.error)),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => context.pop(),
          child: Text(t.settings.customDataDir.cancel),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: anyErrors ? null : _onConfirm,
          child: Text(t.settings.customDataDir.select),
        ),
      ],
    );
  }
}
