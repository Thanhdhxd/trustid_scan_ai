import 'package:flutter/material.dart';

const Color kProdOrderPrimary = Color(0xFF00875A);
const Color kProdOrderPrimaryLight = Color(0xFF36B37E);
const Color kProdOrderBg = Color(0xFF0F2B46);
const Color kProdOrderSurface = Color(0xFF16325B);
const Color kProdOrderFieldBg = Color(0xFF0F2B46);
const Color kProdOrderCardBorder = Color(0x1FFFFFFF);
const Color kProdOrderText = Color(0xFFFFFFFF);
const Color kProdOrderTextSub = Color(0xFFE2E8F0);
const Color kProdOrderTextGray = Color(0xFF94A3B8);
const Color kProdOrderAmber = Color(0xFFF59E0B);

InputDecoration prodOrderInputDeco(
  String? label, {
  String? hint,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) =>
    InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: kProdOrderTextGray, fontSize: 13),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: kProdOrderFieldBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kProdOrderCardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kProdOrderCardBorder),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: kProdOrderPrimaryLight, width: 1.5),
      ),
    );
