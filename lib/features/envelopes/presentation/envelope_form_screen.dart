import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../domain/envelope.dart';
import 'envelope_form_controller.dart';

class EnvelopeFormScreen extends ConsumerStatefulWidget {
  const EnvelopeFormScreen({super.key, this.existingEnvelope});

  final Envelope? existingEnvelope;

  @override
  ConsumerState<EnvelopeFormScreen> createState() => _EnvelopeFormScreenState();
}

class _EnvelopeFormScreenState extends ConsumerState<EnvelopeFormScreen> {
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = widget.existingEnvelope;
    if (existing != null) {
      _nameController.text = existing.name;
      final displayValue =
          existing.allocationMethod == AllocationMethod.percentage
          ? existing.allocationValue * 100
          : existing.allocationValue;
      _valueController.text = displayValue.toStringAsFixed(
        displayValue.truncateToDouble() == displayValue ? 0 : 2,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEditing = widget.existingEnvelope != null;
    final state = ref.watch(
      envelopeFormControllerProvider(widget.existingEnvelope),
    );
    final controller = ref.read(
      envelopeFormControllerProvider(widget.existingEnvelope).notifier,
    );

    ref.listen(envelopeFormControllerProvider(widget.existingEnvelope), (
      previous,
      next,
    ) {
      if (next.saved && (previous?.saved ?? false) == false) {
        Navigator.of(context).pop();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? l10n.envelopeFormTitleEdit : l10n.envelopeFormTitleCreate,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: l10n.envelopeFormNameLabel),
            onChanged: controller.setName,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<AllocationMethod>(
            initialValue: state.method,
            decoration: InputDecoration(
              labelText: l10n.envelopeFormMethodLabel,
            ),
            items: [
              DropdownMenuItem(
                value: AllocationMethod.percentage,
                child: Text(l10n.envelopeFormMethodPercentage),
              ),
              DropdownMenuItem(
                value: AllocationMethod.fixed,
                child: Text(l10n.envelopeFormMethodFixed),
              ),
            ],
            onChanged: (value) {
              if (value != null) controller.setMethod(value);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _valueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: state.method == AllocationMethod.percentage
                  ? l10n.envelopeFormValueLabelPercentage
                  : l10n.envelopeFormValueLabelFixed,
            ),
            onChanged: (value) => controller.setValue(double.tryParse(value)),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text(l10n.envelopeFormReceiverToggle),
            value: state.isRoundingReceiver,
            onChanged: controller.setIsRoundingReceiver,
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              l10n.envelopeFormErrorPrefix(state.errorMessage!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: state.isSubmitting ? null : controller.save,
            child: state.isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.envelopeFormSaveAction),
          ),
        ],
      ),
    );
  }
}
