import 'dart:io';

import 'package:flutter/material.dart';

import '../models/brand_registry.dart';
import '../ui/adaptive/app_icon_button.dart';
import '../ui/adaptive/app_tappable.dart';
import '../ui/app_theme.dart';

/// A station the fill-up form can offer. An empty [id] means typed by hand.
class StationChoice {
  final String id;
  final String name;
  final String brand;

  const StationChoice(this.id, this.name, this.brand);

  @override
  bool operator ==(Object other) =>
      other is StationChoice && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// Small grey caption above a group of controls.
class FormLabel extends StatelessWidget {
  final String text;

  const FormLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
      ),
    );
  }
}

/// Error line under a control that isn't a text field.
class FieldError extends StatelessWidget {
  final String? message;

  const FieldError(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.error,
          ),
        ),
      ),
    );
  }
}

/// One-tap station selection: recent and nearby stations as chips, plus
/// "Other" for typing a name and "More" for the full list.
class StationChips extends StatelessWidget {
  final List<StationChoice> choices;
  final StationChoice? selected;
  final bool isOther;
  final ValueChanged<StationChoice> onSelected;
  final VoidCallback? onOther;
  final VoidCallback? onMore;

  const StationChips({
    super.key,
    required this.choices,
    required this.selected,
    required this.isOther,
    required this.onSelected,
    this.onOther,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in choices)
          ChoiceChip(
            label: Text(c.name),
            selected: !isOther && c == selected,
            onSelected: (_) => onSelected(c),
          ),
        if (onOther != null)
          ChoiceChip(
            avatar: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Other'),
            selected: isOther,
            onSelected: (_) => onOther!(),
          ),
        if (onMore != null)
          ActionChip(
            avatar: const Icon(Icons.expand_more, size: 18),
            label: const Text('More'),
            onPressed: onMore,
          ),
      ],
    );
  }
}

/// Thumbnails of attached photos with remove buttons and an add tile.
class PhotoStrip extends StatelessWidget {
  final List<String> paths;
  final int max;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  const PhotoStrip({
    super.key,
    required this.paths,
    required this.max,
    required this.onAdd,
    required this.onRemove,
  });

  static const _size = 72.0;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (i, path) in paths.indexed)
          SizedBox.square(
            dimension: _size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    cacheWidth: 216,
                    semanticLabel: 'Photo ${i + 1}',
                  ),
                ),
                Positioned(
                  top: -10,
                  right: -10,
                  child: AppIconButton(
                    tooltip: 'Remove photo ${i + 1}',
                    onPressed: () => onRemove(path),
                    icon: const CircleAvatar(
                      radius: 11,
                      backgroundColor: AppColors.ink,
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (paths.length < max)
          Semantics(
            button: true,
            label: 'Add photo',
            onTap: onAdd,
            excludeSemantics: true,
            child: AppTappable(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outline),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Scrollable row of PH fuel brands as round logo buttons, with "Other"
/// at the end for independent stations.
class BrandChips extends StatelessWidget {
  final List<BrandInfo> brands;
  final BrandInfo? selected;
  final bool isOtherSelected;
  final ValueChanged<BrandInfo> onSelected;
  final VoidCallback onOther;

  const BrandChips({
    super.key,
    required this.brands,
    required this.selected,
    required this.isOtherSelected,
    required this.onSelected,
    required this.onOther,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        // Let the row bleed to the sheet edges while lining up with fields.
        clipBehavior: Clip.none,
        children: [
          for (final b in brands)
            _BrandChip(
              label: b.name,
              isSelected: b.name == selected?.name,
              onTap: () => onSelected(b),
              child: b.mark(size: 34),
            ),
          _BrandChip(
            label: 'Other',
            isSelected: isOtherSelected,
            onTap: onOther,
            child: const Icon(Icons.edit_outlined, color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}

class _BrandChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget child;

  const _BrandChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      // excludeSemantics hides the InkWell's action, so declare it here.
      onTap: onTap,
      excludeSemantics: true,
      child: AppTappable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 68,
          child: Column(
            children: [
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 150),
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.ink : AppColors.divider,
                    width: isSelected ? 2.5 : 1,
                  ),
                ),
                child: Center(child: child),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.ink : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
