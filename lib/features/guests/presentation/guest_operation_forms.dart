import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_modal_sheet.dart';
import '../domain/pve_guest.dart';

Future<PveGuestSnapshotRequest?> showGuestSnapshotForm(
  BuildContext context, {
  required PveGuest guest,
}) {
  return showPveModalSheet<PveGuestSnapshotRequest>(
    context: context,
    scrollableBuilder:
        (BuildContext sheetContext, ScrollController scrollController) =>
            _GuestSnapshotForm(
              guest: guest,
              scrollController: scrollController,
            ),
  );
}

Future<PveGuestBackupRequest?> showGuestBackupForm(
  BuildContext context, {
  required List<String> storageNames,
}) {
  if (storageNames.isEmpty) {
    return Future<PveGuestBackupRequest?>.value(null);
  }
  return showPveModalSheet<PveGuestBackupRequest>(
    context: context,
    scrollableBuilder:
        (BuildContext sheetContext, ScrollController scrollController) =>
            _GuestBackupForm(
              storageNames: storageNames,
              scrollController: scrollController,
            ),
  );
}

Future<PveGuestConfigurationChange?> showGuestConfigurationForm(
  BuildContext context, {
  required Map<String, String> configuration,
}) {
  return showPveModalSheet<PveGuestConfigurationChange>(
    context: context,
    scrollableBuilder:
        (BuildContext sheetContext, ScrollController scrollController) =>
            _GuestConfigurationForm(
              configuration: configuration,
              scrollController: scrollController,
            ),
  );
}

class _GuestFormPage extends StatelessWidget {
  const _GuestFormPage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: PveAppleColors.page(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}

class _GuestSnapshotForm extends StatefulWidget {
  const _GuestSnapshotForm({
    required this.guest,
    required this.scrollController,
  });

  final PveGuest guest;
  final ScrollController scrollController;

  @override
  State<_GuestSnapshotForm> createState() => _GuestSnapshotFormState();
}

class _GuestSnapshotFormState extends State<_GuestSnapshotForm> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _includeMemoryState = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = PveGuestSnapshotRequest(
      name: _nameController.text,
      description: _descriptionController.text,
      includeMemoryState: _includeMemoryState,
    );
    return _GuestFormPage(
      title: 'Create Snapshot',
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: <Widget>[
          Text(
            'Capture ${widget.guest.title}',
            style: PveAppleText.title2(context),
          ),
          const SizedBox(height: 6),
          Text(
            'Snapshots use the storage and guest settings already configured in Proxmox.',
            style: PveAppleText.secondary(context),
          ),
          const SizedBox(height: 18),
          CupertinoFormSection.insetGrouped(
            margin: EdgeInsets.zero,
            header: const Text('Snapshot details'),
            children: <Widget>[
              CupertinoTextFormFieldRow(
                prefix: const Text('Name'),
                placeholder: 'before-upgrade',
                controller: _nameController,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
              ),
              CupertinoTextFormFieldRow(
                prefix: const Text('Note'),
                placeholder: 'Optional',
                controller: _descriptionController,
                maxLines: 3,
              ),
              if (widget.guest.kind == GuestKind.virtualMachine)
                CupertinoFormRow(
                  prefix: const Text('Include memory'),
                  helper: const Text(
                    'Lets a running virtual machine resume from this point.',
                  ),
                  child: CupertinoSwitch(
                    value: _includeMemoryState,
                    onChanged: (bool value) {
                      setState(() => _includeMemoryState = value);
                    },
                  ),
                ),
            ],
          ),
          if (_nameController.text.isNotEmpty &&
              !request.hasValidName) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              request.validationMessage!,
              style: PveAppleText.secondary(
                context,
              ).copyWith(color: PveAppleColors.destructive(context)),
            ),
          ],
          const SizedBox(height: 24),
          CupertinoButton.filled(
            onPressed: request.hasValidName
                ? () => Navigator.of(context).pop(request)
                : null,
            child: const Text('Create Snapshot'),
          ),
        ],
      ),
    );
  }
}

class _GuestBackupForm extends StatefulWidget {
  const _GuestBackupForm({
    required this.storageNames,
    required this.scrollController,
  });

  final List<String> storageNames;
  final ScrollController scrollController;

  @override
  State<_GuestBackupForm> createState() => _GuestBackupFormState();
}

class _GuestBackupFormState extends State<_GuestBackupForm> {
  late String _storage = widget.storageNames.first;
  PveGuestBackupMode _mode = PveGuestBackupMode.snapshot;
  String _compression = 'zstd';

  @override
  Widget build(BuildContext context) {
    return _GuestFormPage(
      title: 'Run Backup',
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: <Widget>[
          Text('Backup destination', style: PveAppleText.title2(context)),
          const SizedBox(height: 6),
          Text(
            'Proxmox will create and track the backup task. Existing retention and scheduling remain unchanged.',
            style: PveAppleText.secondary(context),
          ),
          const SizedBox(height: 18),
          CupertinoFormSection.insetGrouped(
            margin: EdgeInsets.zero,
            header: const Text('Options'),
            children: <Widget>[
              CupertinoFormRow(
                prefix: const Text('Storage'),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerRight,
                  onPressed: _selectStorage,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Flexible(
                        child: Text(_storage, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 5),
                      const Icon(
                        CupertinoIcons.chevron_up_chevron_down,
                        size: 15,
                      ),
                    ],
                  ),
                ),
              ),
              CupertinoFormRow(
                prefix: const Text('Mode'),
                child: PveSlidingSegmentedControl<PveGuestBackupMode>(
                  groupValue: _mode,
                  children: const <PveGuestBackupMode, Widget>{
                    PveGuestBackupMode.snapshot: Text('Snapshot'),
                    PveGuestBackupMode.suspend: Text('Suspend'),
                    PveGuestBackupMode.stop: Text('Stop'),
                  },
                  onValueChanged: (PveGuestBackupMode? value) {
                    if (value != null) {
                      setState(() => _mode = value);
                    }
                  },
                ),
              ),
              CupertinoFormRow(
                prefix: const Text('Compression'),
                child: PveSlidingSegmentedControl<String>(
                  groupValue: _compression,
                  children: const <String, Widget>{
                    'zstd': Text('Zstd'),
                    'gzip': Text('Gzip'),
                  },
                  onValueChanged: (String? value) {
                    if (value != null) {
                      setState(() => _compression = value);
                    }
                  },
                ),
              ),
            ],
          ),
          if (_mode == PveGuestBackupMode.stop) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'Stop mode powers down the guest for the backup. Confirm this only during a maintenance window.',
              style: PveAppleText.secondary(
                context,
              ).copyWith(color: PveAppleColors.warning(context)),
            ),
          ],
          const SizedBox(height: 24),
          CupertinoButton.filled(
            onPressed: () => Navigator.of(context).pop(
              PveGuestBackupRequest(
                storage: _storage,
                mode: _mode,
                compression: _compression,
              ),
            ),
            child: const Text('Start Backup'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectStorage() async {
    final selected = await showCupertinoModalPopup<String>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Backup storage'),
        actions: <Widget>[
          for (final storage in widget.storageNames)
            CupertinoActionSheetAction(
              isDefaultAction: storage == _storage,
              onPressed: () => Navigator.of(context).pop(storage),
              child: Text(storage),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _storage = selected);
    }
  }
}

class _GuestConfigurationForm extends StatefulWidget {
  const _GuestConfigurationForm({
    required this.configuration,
    required this.scrollController,
  });

  final Map<String, String> configuration;
  final ScrollController scrollController;

  @override
  State<_GuestConfigurationForm> createState() =>
      _GuestConfigurationFormState();
}

class _GuestConfigurationFormState extends State<_GuestConfigurationForm> {
  late final int? _initialCores = int.tryParse(
    widget.configuration['cores'] ?? '',
  );
  late final int? _initialMemory = int.tryParse(
    widget.configuration['memory'] ?? '',
  );
  late final bool? _initialOnBoot = _parseBoolean(
    widget.configuration['onboot'],
  );
  late final String _initialDescription =
      widget.configuration['description'] ?? '';
  late final TextEditingController _coresController = TextEditingController(
    text: _initialCores?.toString() ?? '',
  );
  late final TextEditingController _memoryController = TextEditingController(
    text: _initialMemory?.toString() ?? '',
  );
  late final TextEditingController _descriptionController =
      TextEditingController(text: _initialDescription);
  late bool _onBoot = _initialOnBoot ?? false;

  @override
  void dispose() {
    _coresController.dispose();
    _memoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cores = _positiveInteger(_coresController.text);
    final memory = _positiveInteger(_memoryController.text);
    // Proxmox treats an omitted field as unchanged. A blank value must not
    // look like a successful attempt to remove an existing CPU or memory
    // setting, because that is neither an intentional reset nor a supported
    // safe edit in this companion.
    final validCores = _hasValidResourceValue(
      text: _coresController.text,
      parsedValue: cores,
      initialValue: _initialCores,
    );
    final validMemory = _hasValidResourceValue(
      text: _memoryController.text,
      parsedValue: memory,
      initialValue: _initialMemory,
    );
    return _GuestFormPage(
      title: 'Edit Configuration',
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: <Widget>[
          Text('Safe guest settings', style: PveAppleText.title2(context)),
          const SizedBox(height: 6),
          Text(
            'Changes are sent directly to Proxmox. Hardware changes may require the guest to be stopped before they take effect.',
            style: PveAppleText.secondary(context),
          ),
          const SizedBox(height: 18),
          CupertinoFormSection.insetGrouped(
            margin: EdgeInsets.zero,
            header: const Text('Resources'),
            children: <Widget>[
              CupertinoTextFormFieldRow(
                prefix: const Text('CPU cores'),
                placeholder: 'Not reported',
                controller: _coresController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              CupertinoTextFormFieldRow(
                prefix: const Text('Memory'),
                placeholder: 'MiB',
                controller: _memoryController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          if (!validCores || !validMemory) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'CPU cores and memory must be whole positive numbers.',
              style: PveAppleText.secondary(
                context,
              ).copyWith(color: PveAppleColors.destructive(context)),
            ),
          ],
          CupertinoFormSection.insetGrouped(
            margin: const EdgeInsets.only(top: 18),
            header: const Text('Startup'),
            children: <Widget>[
              CupertinoFormRow(
                prefix: const Text('Start at boot'),
                child: CupertinoSwitch(
                  value: _onBoot,
                  onChanged: (bool value) => setState(() => _onBoot = value),
                ),
              ),
            ],
          ),
          CupertinoFormSection.insetGrouped(
            margin: const EdgeInsets.only(top: 18),
            header: const Text('Description'),
            children: <Widget>[
              CupertinoTextFormFieldRow(
                placeholder: 'Optional note',
                controller: _descriptionController,
                maxLines: 4,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          const SizedBox(height: 24),
          CupertinoButton.filled(
            onPressed: validCores && validMemory && _hasChanges(cores, memory)
                ? () => Navigator.of(context).pop(_change(cores, memory))
                : null,
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  bool _hasChanges(int? cores, int? memory) {
    return cores != _initialCores ||
        memory != _initialMemory ||
        _onBoot != (_initialOnBoot ?? false) ||
        _descriptionController.text != _initialDescription;
  }

  PveGuestConfigurationChange _change(int? cores, int? memory) {
    return PveGuestConfigurationChange(
      cores: cores != _initialCores ? cores : null,
      memoryMiB: memory != _initialMemory ? memory : null,
      onBoot: _onBoot != (_initialOnBoot ?? false) ? _onBoot : null,
      description: _descriptionController.text != _initialDescription
          ? _descriptionController.text
          : null,
    );
  }

  int? _positiveInteger(String value) {
    final parsed = int.tryParse(value.trim());
    return parsed != null && parsed > 0 ? parsed : null;
  }

  bool _hasValidResourceValue({
    required String text,
    required int? parsedValue,
    required int? initialValue,
  }) => text.trim().isEmpty ? initialValue == null : parsedValue != null;

  bool? _parseBoolean(String? value) => switch (value?.trim().toLowerCase()) {
    '1' || 'true' || 'yes' => true,
    '0' || 'false' || 'no' => false,
    _ => null,
  };
}
