import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/veterinary_request.dart';
import '../repositories/veterinary_request_repository.dart';
import 'notification_service.dart';

/// Lokalni fallback: obavijest veterinaru dok je app otvoren (novi karton).
class VetIntakeAlertListener extends ConsumerStatefulWidget {
  const VetIntakeAlertListener({
    super.key,
    required this.role,
    required this.child,
  });

  final String role;
  final Widget child;

  @override
  ConsumerState<VetIntakeAlertListener> createState() =>
      _VetIntakeAlertListenerState();
}

class _VetIntakeAlertListenerState extends ConsumerState<VetIntakeAlertListener> {
  final Set<String> _seenRequestIds = {};
  bool _skipInitial = true;

  bool get _isVet => widget.role == 'veterinarian';

  @override
  Widget build(BuildContext context) {
    if (_isVet) {
      ref.listen<AsyncValue<List<VeterinaryRequest>>>(
        vetIncomingRequestsProvider,
        (previous, next) {
          next.whenData(_handleRequestsUpdate);
        },
      );
    }

    return widget.child;
  }

  void _handleRequestsUpdate(List<VeterinaryRequest> requests) {
    if (!_isVet) return;

    if (_skipInitial) {
      for (final request in requests) {
        _seenRequestIds.add(request.id);
      }
      _skipInitial = false;
      return;
    }

    for (final request in requests) {
      if (_seenRequestIds.contains(request.id)) continue;
      if (request.status.toLowerCase() != 'pending') continue;

      _seenRequestIds.add(request.id);
      NotificationService().showVetIntakeAlert(
        requestId: request.id,
        animalName: request.animalName,
        clientName: request.clientName,
      );
    }
  }
}
