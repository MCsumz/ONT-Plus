import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/features/profile/presentation/utils/profile_switch_coordinator.dart';
import 'package:opennutritracker/features/sync/data/sync_store.dart';
import 'package:opennutritracker/features/sync/data/sync_transport.dart';
import 'package:opennutritracker/features/sync/domain/sync_cipher.dart';
import 'package:opennutritracker/features/sync/domain/sync_engine.dart';
import 'package:opennutritracker/features/sync/domain/sync_offer.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:qr_flutter/qr_flutter.dart';

enum SyncRole {
  /// Shows the QR code and waits; its version wins a both-sides edit.
  host,

  /// Scans the other phone's code.
  join,
}

/// Phone-to-phone sync: one phone shows a code, the other scans it, the two
/// exchange their data over the local network, encrypted with the key in
/// the code, and both merge — see [SyncEngine.apply].
///
/// Pops with true once this phone applied a sync.
class PhoneSyncScreen extends StatefulWidget {
  final SyncRole role;

  /// Set when opened from the first-time setup: this phone has no profile
  /// yet and takes the other phone's.
  final SyncOnboarding? onboarding;

  const PhoneSyncScreen({super.key, required this.role, this.onboarding});

  @override
  State<PhoneSyncScreen> createState() => _PhoneSyncScreenState();
}

enum _Stage {
  preparing,
  noNetwork,
  showingCode,
  scanning,
  exchanging,
  merging,
  waitingForOther,
  done,
  failed,
}

class _PhoneSyncScreenState extends State<PhoneSyncScreen> {
  final _engine = SyncEngine();
  _Stage _stage = _Stage.preparing;
  double? _progress;
  SyncOffer? _offer;
  SyncHost? _host;
  SyncExchange? _exchange;
  SyncSummary? _summary;
  bool? _otherPhoneOk;
  String? _error;
  MobileScannerController? _camera;
  bool _scanned = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    unawaited(_host?.close());
    unawaited(_exchange?.close());
    unawaited(_camera?.dispose());
    super.dispose();
  }

  void _set(_Stage stage, {double? progress}) {
    if (!mounted) return;
    setState(() {
      _stage = stage;
      _progress = progress;
    });
  }

  void _start() {
    _scanned = false;
    _summary = null;
    _error = null;
    _otherPhoneOk = null;
    if (widget.role == SyncRole.host) {
      unawaited(_runHost());
    } else {
      _camera ??= MobileScannerController(
        formats: const [BarcodeFormat.qrCode],
      );
      _set(_Stage.scanning);
    }
  }

  Future<void> _runHost() async {
    _set(_Stage.preparing);
    try {
      final nextBaseId = SyncStore.newId();
      final bundle = await _engine.buildBundle(nextBaseId: nextBaseId);
      final host = await SyncHost.start(bundle);
      if (host == null) {
        _set(_Stage.noNetwork);
        return;
      }
      _host = host;
      if (!mounted) return;
      setState(() {
        _offer = host.offer;
        _stage = _Stage.showingCode;
      });
      final exchange = await host.waitForPartner(
        onConnected: () => _set(_Stage.exchanging),
        onReceive: _progressOf,
        onSend: _progressOf,
      );
      _exchange = exchange;
      _set(_Stage.merging);
      final summary = await _engine.apply(
        exchange.remoteBundle,
        localIsHost: true,
        localNextBaseId: nextBaseId,
        onboarding: widget.onboarding,
      );
      _summary = summary;
      _set(_Stage.waitingForOther);
      final ok = await exchange.readAck();
      _otherPhoneOk = ok;
      _finish();
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_scanned) return;
    final offer = SyncOffer.tryParse(capture.barcodes.firstOrNull?.rawValue);
    if (offer == null) return;
    _scanned = true;
    unawaited(_camera?.stop());
    await _runJoin(offer);
  }

  Future<void> _runJoin(SyncOffer offer) async {
    _set(_Stage.preparing);
    SyncExchange? exchange;
    try {
      final bundle = await _engine.buildBundle(nextBaseId: SyncStore.newId());
      _set(_Stage.exchanging);
      exchange = await SyncJoin.exchange(
        offer,
        bundle,
        onSend: _progressOf,
        onReceive: _progressOf,
      );
      _exchange = exchange;
      _set(_Stage.merging);
      _summary = await _engine.apply(
        exchange.remoteBundle,
        localIsHost: false,
        localNextBaseId: SyncStore.newId(),
        onboarding: widget.onboarding,
      );
      await exchange.sendAck(ok: true);
      _finish();
    } catch (e) {
      if (exchange != null) unawaited(exchange.sendAck(ok: false));
      _fail(e);
    }
  }

  void _progressOf(int done, int total) {
    if (total <= 0) return;
    _set(_stage, progress: done / total);
  }

  void _finish() {
    // Every tab reloads from the merged data, as after a profile switch.
    ProfileSwitchCoordinator.reloadTabBlocs();
    _set(_Stage.done);
  }

  void _fail(Object error) {
    if (!mounted) return;
    final s = S.of(context);
    final message = switch (error) {
      SyncException(reason: SyncFailure.noProfileAnywhere) =>
        s.syncErrorNoProfile,
      SyncException(reason: SyncFailure.unreadableBundle) =>
        s.syncErrorUnreadable,
      SocketException() || TimeoutException() => s.syncErrorConnect,
      SyncCipherException() => s.syncErrorConnect,
      _ => s.syncErrorGeneric,
    };
    setState(() {
      _error = message;
      _stage = _Stage.failed;
    });
  }

  void _close() {
    Navigator.of(context).pop(_stage == _Stage.done);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.syncTitle)),
      body: SafeArea(
        child: _stage == _Stage.scanning
            ? _buildScanner(context)
            : SingleChildScrollView(
                padding: const EdgeInsets.all(Dimens.spacing24),
                child: _buildBody(context),
              ),
      ),
    );
  }

  Widget _buildScanner(BuildContext context) {
    return Stack(
      children: [
        Semantics(
          identifier: 'sync-scanner',
          child: MobileScanner(controller: _camera, onDetect: _onDetect),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            color: Colors.black54,
            padding: const EdgeInsets.all(Dimens.spacing16),
            child: Text(
              S.of(context).syncScanHint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    switch (_stage) {
      case _Stage.showingCode:
        return Column(
          children: [
            Text(s.syncIntro, style: theme.textTheme.bodyMedium),
            const SizedBox(height: Dimens.spacing24),
            Semantics(
              identifier: 'sync-qr-code',
              child: Container(
                padding: const EdgeInsets.all(Dimens.spacing12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: Dimens.borderRadiusM,
                ),
                child: QrImageView(
                  data: _offer!.encode(),
                  size: 260,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: Dimens.spacing24),
            Text(
              s.syncShowCodeHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        );
      case _Stage.preparing:
        return _status(context, s.syncPreparing);
      case _Stage.exchanging:
        return _status(context, s.syncExchanging, progress: _progress);
      case _Stage.merging:
        return _status(context, s.syncMerging);
      case _Stage.waitingForOther:
        return _status(context, s.syncWaitingForOther);
      case _Stage.noNetwork:
        return _message(context, Icons.wifi_off_rounded, s.syncNoNetwork);
      case _Stage.failed:
        return _message(context, Icons.error_outline_rounded, _error ?? '');
      case _Stage.done:
        return _buildDone(context);
      case _Stage.scanning:
        return const SizedBox.shrink();
    }
  }

  Widget _status(BuildContext context, String text, {double? progress}) {
    return Column(
      children: [
        const SizedBox(height: Dimens.spacing32 + Dimens.spacing16),
        SizedBox(width: 220, child: LinearProgressIndicator(value: progress)),
        const SizedBox(height: Dimens.spacing16),
        Text(text, textAlign: TextAlign.center),
      ],
    );
  }

  Widget _message(BuildContext context, IconData icon, String text) {
    final s = S.of(context);
    return Column(
      children: [
        const SizedBox(height: Dimens.spacing32),
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: Dimens.spacing16),
        Text(text, textAlign: TextAlign.center),
        const SizedBox(height: Dimens.spacing24),
        Semantics(
          identifier: 'sync-retry',
          child: FilledButton(
            onPressed: () {
              _scanned = false;
              unawaited(_camera?.start());
              _start();
            },
            child: Text(s.retryLabel),
          ),
        ),
      ],
    );
  }

  Widget _buildDone(BuildContext context) {
    final s = S.of(context);
    final summary = _summary!;
    final theme = Theme.of(context);
    final changed = summary.added + summary.updated + summary.removed > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Dimens.spacing24),
        Icon(
          Icons.check_circle_rounded,
          size: 56,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: Dimens.spacing12),
        Text(
          s.syncDoneTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: Dimens.spacing16),
        Text(
          changed
              ? s.syncChangesSummary(
                  summary.added,
                  summary.updated,
                  summary.removed,
                )
              : s.syncNothingChanged,
          textAlign: TextAlign.center,
        ),
        if (summary.profileReceived) ...[
          const SizedBox(height: Dimens.spacing8),
          Text(s.syncProfileReceived, textAlign: TextAlign.center),
        ],
        if (summary.firstSync) ...[
          const SizedBox(height: Dimens.spacing8),
          Text(
            s.syncFirstSyncNote,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (summary.conflicts > 0) ...[
          const SizedBox(height: Dimens.spacing8),
          Text(
            s.syncConflictsNote(summary.conflicts),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (_otherPhoneOk == false) ...[
          const SizedBox(height: Dimens.spacing8),
          Text(
            s.syncOtherPhoneFailed,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: Dimens.spacing24),
        Semantics(
          identifier: 'sync-done',
          child: FilledButton(onPressed: _close, child: Text(s.dialogOKLabel)),
        ),
      ],
    );
  }
}

/// Opens the sync screen; completes with true once this phone was synced.
Future<bool> openPhoneSync(
  BuildContext context,
  SyncRole role, {
  SyncOnboarding? onboarding,
}) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => PhoneSyncScreen(role: role, onboarding: onboarding),
    ),
  );
  return result ?? false;
}
