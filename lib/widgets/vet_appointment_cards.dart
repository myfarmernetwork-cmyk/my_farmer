import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/veterinary_request.dart';
import '../repositories/veterinary_request_repository.dart';
import '../utils/vet_appointment_formatter.dart';

class VetAppointmentOwnerCard extends ConsumerStatefulWidget {
  const VetAppointmentOwnerCard({
    super.key,
    required this.request,
  });

  final VeterinaryRequest request;

  @override
  ConsumerState<VetAppointmentOwnerCard> createState() =>
      _VetAppointmentOwnerCardState();
}

class _VetAppointmentOwnerCardState
    extends ConsumerState<VetAppointmentOwnerCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String successKey) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successKey.tr()),
          backgroundColor: Colors.green[700],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common_error'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() {
    return _run(
      () => ref
          .read(veterinaryRequestRepositoryProvider)
          .confirmAppointment(requestId: widget.request.id),
      'vet_appointment_confirmed_snack',
    );
  }

  Future<void> _decline() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text('vet_appointment_decline'.tr()),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'vet_appointment_decline_reason_hint'.tr(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('cart_cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text('vet_appointment_decline'.tr()),
            ),
          ],
        );
      },
    );
    if (reason == null || !mounted) return;

    await _run(
      () => ref.read(veterinaryRequestRepositoryProvider).declineAppointment(
            requestId: widget.request.id,
            reason: reason,
          ),
      'vet_appointment_declined_snack',
    );
  }

  Future<void> _counter() async {
    final result = await showModalBottomSheet<_CounterResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _CounterAppointmentSheet(),
    );
    if (result == null || !mounted) return;

    await _run(
      () => ref
          .read(veterinaryRequestRepositoryProvider)
          .counterProposeAppointment(
            requestId: widget.request.id,
            appointmentAt: result.dateTime,
            note: result.note,
          ),
      'vet_appointment_counter_sent_snack',
    );
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;

    if (request.isPending) {
      return _StatusCard(
        color: Colors.orange,
        icon: Icons.hourglass_top_rounded,
        title: 'vet_appointment_waiting_title'.tr(),
        body: 'vet_appointment_waiting_body'.tr(
          namedArgs: {'vet': request.vetName},
        ),
      );
    }

    if (request.isAppointmentConfirmed &&
        request.activeAppointmentDateTime != null) {
      return _StatusCard(
        color: Colors.green,
        icon: Icons.event_available_rounded,
        title: 'vet_appointment_confirmed_title'.tr(),
        body: 'vet_appointment_confirmed_label'.tr(
          namedArgs: {
            'datetime': VetAppointmentFormatter.formatDateTime(
              context,
              request.activeAppointmentDateTime!,
            ),
            'vet': request.vetName,
          },
        ),
      );
    }

    if (request.isAppointmentDeclined) {
      return _StatusCard(
        color: Colors.grey,
        icon: Icons.event_busy_rounded,
        title: 'vet_appointment_decline'.tr(),
        body: request.declineReason.trim().isNotEmpty
            ? request.declineReason.trim()
            : 'vet_appointment_status_declined'.tr(),
      );
    }

    if (request.hasOwnerCounter && request.ownerCounterAt != null) {
      return _StatusCard(
        color: Colors.amber,
        icon: Icons.schedule_send_rounded,
        title: 'vet_appointment_status_counter'.tr(),
        body: 'vet_appointment_counter_title'.tr(
          namedArgs: {
            'datetime': VetAppointmentFormatter.formatDateTime(
              context,
              request.ownerCounterAt!.toDate(),
            ),
          },
        ),
        subtitle: request.ownerCounterNote.trim().isNotEmpty
            ? request.ownerCounterNote.trim()
            : null,
      );
    }

    if (request.hasProposedAppointment && request.proposedAt != null) {
      return Card(
        elevation: 2,
        color: Colors.teal.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.teal.shade300, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.event_rounded, color: Colors.teal.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'vet_appointment_proposed_title'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.teal.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'vet_appointment_proposed_label'.tr(
                  namedArgs: {
                    'datetime': VetAppointmentFormatter.formatDateTime(
                      context,
                      request.proposedAt!.toDate(),
                    ),
                    'vet': request.vetName,
                  },
                ),
                style: const TextStyle(fontSize: 15, height: 1.45),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _confirm,
                      icon: const Icon(Icons.check_rounded),
                      label: Text('vet_appointment_confirm'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _counter,
                      icon: const Icon(Icons.update_rounded),
                      label: Text('vet_appointment_counter'.tr()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : _decline,
                child: Text('vet_appointment_decline'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
    this.subtitle,
  });

  final MaterialColor color;
  final IconData icon;
  final String title;
  final String body;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: color.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.shade300, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: color.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(body, style: const TextStyle(fontSize: 15, height: 1.45)),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CounterResult {
  const _CounterResult({required this.dateTime, this.note});

  final DateTime dateTime;
  final String? note;
}

class _CounterAppointmentSheet extends StatefulWidget {
  const _CounterAppointmentSheet();

  @override
  State<_CounterAppointmentSheet> createState() =>
      _CounterAppointmentSheetState();
}

class _CounterAppointmentSheetState extends State<_CounterAppointmentSheet> {
  DateTime? _selected;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await VetAppointmentFormatter.pickDateTime(context);
    if (picked != null) setState(() => _selected = picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'vet_appointment_counter_sheet_title'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(
              _selected == null
                  ? 'vet_appointment_select_datetime'.tr()
                  : VetAppointmentFormatter.formatDateTime(context, _selected!),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'vet_appointment_counter_note'.tr(),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _selected == null
                ? null
                : () => Navigator.pop(
                      context,
                      _CounterResult(
                        dateTime: _selected!,
                        note: _noteController.text.trim(),
                      ),
                    ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text('vet_appointment_counter_send'.tr()),
          ),
        ],
      ),
    );
  }
}

class VetAppointmentVetPanel extends ConsumerStatefulWidget {
  const VetAppointmentVetPanel({super.key, required this.request});

  final VeterinaryRequest request;

  @override
  ConsumerState<VetAppointmentVetPanel> createState() =>
      _VetAppointmentVetPanelState();
}

class _VetAppointmentVetPanelState
    extends ConsumerState<VetAppointmentVetPanel> {
  bool _busy = false;

  Future<void> _acceptCounter() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(veterinaryRequestRepositoryProvider)
          .acceptOwnerCounterAppointment(requestId: widget.request.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('vet_appointment_vet_accepted_snack'.tr()),
          backgroundColor: Colors.green[700],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common_error'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _proposeNew() async {
    final picked = await VetAppointmentFormatter.pickDateTime(context);
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(veterinaryRequestRepositoryProvider)
          .vetProposeNewAppointment(
            requestId: widget.request.id,
            appointmentAt: picked,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('vet_appointment_confirmed_snack'.tr()),
          backgroundColor: Colors.green[700],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('common_error'.tr(namedArgs: {'error': '$e'})),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final children = <Widget>[];

    if (request.ownerPreferredDateTime != null && !request.hasOwnerCounter) {
      children.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'vet_appointment_owner_preferred_title'.tr(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'vet_appointment_owner_preferred_label'.tr(
                  namedArgs: {
                    'datetime': VetAppointmentFormatter.formatDateTime(
                      context,
                      request.ownerPreferredDateTime!,
                    ),
                  },
                ),
              ),
              if (request.ownerPreferredNote.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(request.ownerPreferredNote.trim()),
              ],
            ],
          ),
        ),
      );
    }

    if (request.hasOwnerCounter) {
      children.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'vet_appointment_counter_title'.tr(
                  namedArgs: {
                    'datetime': VetAppointmentFormatter.formatDateTime(
                      context,
                      request.ownerCounterAt!.toDate(),
                    ),
                  },
                ),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (request.ownerCounterNote.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(request.ownerCounterNote.trim()),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _busy ? null : _acceptCounter,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                      ),
                      child: Text('vet_appointment_vet_accept_counter'.tr()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : _proposeNew,
                      child: Text('vet_appointment_vet_propose_new'.tr()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
        ],
      ),
    );
  }
}

class VetAppointmentVetProposalFields extends StatelessWidget {
  const VetAppointmentVetProposalFields({
    super.key,
    required this.enabled,
    required this.selectedDateTime,
    required this.onEnabledChanged,
    required this.onPickDateTime,
  });

  final bool enabled;
  final DateTime? selectedDateTime;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onPickDateTime;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: enabled,
          onChanged: onEnabledChanged,
          title: Text('vet_appointment_vet_propose_checkbox'.tr()),
        ),
        if (enabled) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onPickDateTime,
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(
              selectedDateTime == null
                  ? 'vet_appointment_select_datetime'.tr()
                  : VetAppointmentFormatter.formatDateTime(
                      context,
                      selectedDateTime!,
                    ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
