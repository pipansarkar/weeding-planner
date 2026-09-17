import 'package:flutter/material.dart';

/// Opens [page] as a full-screen route with a slide-up-from-bottom
/// transition, matching a native "add item" sheet rather than a page push.
Future<T?> showFormSheet<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    ),
  );
}

/// A full-screen "add/edit" form, opened via [showFormSheet], replacing the
/// old cramped [AlertDialog] forms. Gives every entity screen (Checklist,
/// Budget, Guests, Vendors, ...) the same look: a sticky header with
/// Cancel/Save, optional History/Delete actions, and content organized into
/// [FormSection]s.
class FormSheet extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final VoidCallback? onSave;
  final VoidCallback? onDelete;
  final VoidCallback? onHistory;
  final String saveLabel;
  final bool saving;

  const FormSheet({
    super.key,
    required this.title,
    required this.children,
    required this.onSave,
    this.onDelete,
    this.onHistory,
    this.saveLabel = 'Save',
    this.saving = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title),
        actions: [
          if (onHistory != null)
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'History',
              onPressed: onHistory,
            ),
          if (onDelete != null)
            IconButton(
              icon: Icon(Icons.delete_outline, color: scheme.error),
              tooltip: 'Delete',
              onPressed: onDelete,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: children,
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: FilledButton(
            onPressed: saving ? null : onSave,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : Text(saveLabel),
          ),
        ),
      ),
    );
  }
}

/// A titled, icon-led card grouping related fields together, e.g. "Details",
/// "Schedule", "Payment".
class FormSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  const FormSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._withGaps(children),
        ],
      ),
    );
  }

  List<Widget> _withGaps(List<Widget> items) {
    final result = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) result.add(const SizedBox(height: 12));
      result.add(items[i]);
    }
    return result;
  }
}

/// A tappable field styled like a [TextField] but for pickers (date, time)
/// that open another widget instead of taking direct keyboard input.
class FormPickerField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final Color? valueColor;

  const FormPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = Theme.of(context).inputDecorationTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: decoration.filled,
          fillColor: decoration.fillColor,
          border: decoration.border,
          enabledBorder: decoration.enabledBorder,
          suffixIcon: Icon(icon, size: 20),
        ),
        child: Text(
          value,
          style: TextStyle(color: valueColor),
        ),
      ),
    );
  }
}
