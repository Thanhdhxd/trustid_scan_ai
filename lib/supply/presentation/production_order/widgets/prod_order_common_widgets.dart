import 'package:flutter/material.dart';
import '../constants/prod_order_constants.dart';

class ProdOrderFieldLabel extends StatelessWidget {
  final String label;
  final bool isRequired;

  const ProdOrderFieldLabel(this.label, {super.key, this.isRequired = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: isRequired ? '* ' : '',
          style: const TextStyle(
            color: Color(0xFFFF6B6B),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          children: [
            TextSpan(
              text: label,
              style: const TextStyle(
                color: kProdOrderTextSub,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProdOrderSourceOptionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;
  final String? badge;

  const ProdOrderSourceOptionChip({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.activeColor = kProdOrderPrimary,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.18) : kProdOrderSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? Icons.check_circle_rounded : icon,
                size: 14,
                color: isSelected ? activeColor : kProdOrderTextGray,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : kProdOrderTextSub,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              if (badge != null && badge!.isNotEmpty && badge != '0') ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? activeColor : const Color(0xFF332A00),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kProdOrderAmber.withOpacity(0.6)),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      color: isSelected ? Colors.white : kProdOrderAmber,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ProdOrderSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const ProdOrderSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kProdOrderSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kProdOrderCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: kProdOrderPrimaryLight, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: kProdOrderText,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class ProdOrderParamBox extends StatelessWidget {
  final String label;
  final String value;
  final bool isReadOnly;

  const ProdOrderParamBox(
    this.label,
    this.value, {
    super.key,
    this.isReadOnly = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: kProdOrderTextGray, fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: kProdOrderFieldBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kProdOrderCardBorder),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class ProdOrderSpinBox extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int>? onChanged;

  const ProdOrderSpinBox(
    this.label,
    this.value,
    this.onChanged, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: kProdOrderTextGray, fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: kProdOrderFieldBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kProdOrderCardBorder),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: onChanged != null && value > 0 ? () => onChanged!(value - 1) : null,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                child: Container(
                  width: 40,
                  height: double.infinity,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.remove,
                    size: 18,
                    color: (onChanged != null && value > 0) ? Colors.white : Colors.white24,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              InkWell(
                onTap: onChanged != null ? () => onChanged!(value + 1) : null,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                child: Container(
                  width: 40,
                  height: double.infinity,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.add,
                    size: 18,
                    color: onChanged != null ? Colors.white : Colors.white24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
