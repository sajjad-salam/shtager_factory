import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../telegram_backup.dart';
import '../ui.dart';

/// نافذة اسم المعمل (للإضافة والتعديل). ترجع الاسم أو null.
Future<String?> _askFactoryName(
  BuildContext context, {
  required String title,
  required String action,
  String initial = '',
}) async {
  final name = TextEditingController(text: initial);
  final key = GlobalKey<FormState>();
  final value = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Form(
        key: key,
        child: TextFormField(
          controller: name,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'اسم المعمل',
            prefixIcon: Icon(Icons.factory_outlined),
          ),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'اكتب اسم المعمل' : null,
          onFieldSubmitted: (_) {
            if (key.currentState!.validate()) {
              Navigator.pop(dialogContext, name.text.trim());
            }
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () {
            if (key.currentState!.validate()) {
              Navigator.pop(dialogContext, name.text.trim());
            }
          },
          child: Text(action),
        ),
      ],
    ),
  );
  return value == null || value.isEmpty ? null : value;
}

Future<FactoryLocation?> addFactoryFlow(BuildContext context) async {
  final name = await _askFactoryName(
    context,
    title: 'إضافة معمل',
    action: 'إضافة',
  );
  if (name == null) return null;
  final factory = await AppStore.instance.addFactory(name);
  TelegramBackup.instance.backupNow(reason: 'إضافة معمل ${factory.name}');
  if (context.mounted) toast(context, 'انضاف ${factory.name} ✓');
  return factory;
}

Future<void> renameFactoryFlow(
  BuildContext context,
  FactoryLocation factory,
) async {
  final name = await _askFactoryName(
    context,
    title: 'تعديل اسم المعمل',
    action: 'حفظ',
    initial: factory.name,
  );
  if (name == null) return;
  await AppStore.instance.renameFactory(factory, name);
  TelegramBackup.instance.backupNow(reason: 'تعديل اسم معمل');
}

/// يرجع true إذا انحذف.
Future<bool> deleteFactoryFlow(
  BuildContext context,
  FactoryLocation factory,
) async {
  final store = AppStore.instance;
  if (store.factories.length <= 1) {
    toast(context, 'لازم يبقى معمل واحد على الأقل', error: true);
    return false;
  }
  final purchases = store.incomingOf(factory.id).length;
  final ok = await confirm(
    context,
    'حذف ${factory.name}؟',
    'تنحذف مشترياته ($purchases وصل).\nحسابات الخلفات ما تتأثر.',
  );
  if (!ok) return false;
  await store.deleteFactory(factory.id);
  TelegramBackup.instance.backupNow(reason: 'حذف معمل ${factory.name}');
  return true;
}
