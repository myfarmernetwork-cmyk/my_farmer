import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class VetAppointmentFormatter {
  VetAppointmentFormatter._();

  static String formatDateTime(BuildContext context, DateTime dateTime) {
    return DateFormat.yMMMd(context.locale.toString())
        .add_Hm()
        .format(dateTime);
  }

  static DateTime combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  static Future<DateTime?> pickDateTime(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'vet_appointment_select_datetime'.tr(),
    );
    if (date == null || !context.mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
      helpText: 'vet_appointment_preferred_time'.tr(),
    );
    if (time == null) return null;

    return combineDateAndTime(date, time);
  }
}
