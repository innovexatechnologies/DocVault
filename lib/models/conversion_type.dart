import 'package:flutter/material.dart';

enum ConversionType {
  // ==========================================================================
  // PDF
  // ==========================================================================

  pdf(
    id: 'pdf',
    label: 'PDF Document',
    shortName: 'PDF',
    extension: 'pdf',
    mimeType: 'application/pdf',

    // Modern PDF icon
    icon: Icons.picture_as_pdf_rounded,

    // Elegant red
    badgeColor: Color(0xFFE53935),

    // Premium green gradient
    gradientStart: Color(0xFF007A5E),
    gradientEnd: Color(0xFF00B386),
  ),

  // ==========================================================================
  // WORD / DOCS
  // ==========================================================================

  docs(
    id: 'docs',
    label: 'Word Document',
    shortName: 'DOCX',
    extension: 'docx',
    mimeType:
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',

    icon: Icons.description_rounded,

    // Modern blue
    badgeColor: Color(0xFF1976D2),

    // Blue gradient
    gradientStart: Color(0xFF1565C0),
    gradientEnd: Color(0xFF42A5F5),
  ),

  // ==========================================================================
  // POWERPOINT
  // ==========================================================================

  ppt(
    id: 'ppt',
    label: 'PowerPoint Presentation',
    shortName: 'PPT',
    extension: 'pptx',
    mimeType:
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',

    icon: Icons.slideshow_rounded,

    // Elegant PowerPoint orange
    badgeColor: Color(0xFFE65100),

    // Orange gradient
    gradientStart: Color(0xFFE65100),
    gradientEnd: Color(0xFFFF8A50),
  );

  // ==========================================================================
  // PROPERTIES
  // ==========================================================================

  final String id;

  final String label;

  final String shortName;

  final String extension;

  final String mimeType;

  final IconData icon;

  final Color badgeColor;

  final Color gradientStart;

  final Color gradientEnd;

  // ==========================================================================
  // CONSTRUCTOR
  // ==========================================================================

  const ConversionType({
    required this.id,
    required this.label,
    required this.shortName,
    required this.extension,
    required this.mimeType,
    required this.icon,
    required this.badgeColor,
    required this.gradientStart,
    required this.gradientEnd,
  });

  // ==========================================================================
  // GRADIENT
  // ==========================================================================

  /// Returns the gradient used by modern document cards.
  LinearGradient get gradient {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        gradientStart,
        gradientEnd,
      ],
    );
  }

  // ==========================================================================
  // SOFT BACKGROUND COLOR
  // ==========================================================================

  /// Light transparent background for icons/cards.
  Color get softColor {
    return badgeColor.withValues(
      alpha: 0.10,
    );
  }

  // ==========================================================================
  // FILE NAME
  // ==========================================================================

  /// Returns a file name with the correct extension.
  String buildFileName(String name) {
    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      return 'document.$extension';
    }

    final lowerName =
        cleanName.toLowerCase();

    if (lowerName.endsWith('.$extension')) {
      return cleanName;
    }

    return '$cleanName.$extension';
  }

  // ==========================================================================
  // FILE NAME -> CONVERSION TYPE
  // ==========================================================================

  /// Resolves ConversionType from a file name or complete file path.
  static ConversionType fromFileName(
    String fileName,
  ) {
    final lower =
        fileName.trim().toLowerCase();

    if (lower.endsWith('.docx') ||
        lower.endsWith('.doc')) {
      return ConversionType.docs;
    }

    if (lower.endsWith('.pptx') ||
        lower.endsWith('.ppt')) {
      return ConversionType.ppt;
    }

    if (lower.endsWith('.pdf')) {
      return ConversionType.pdf;
    }

    // Default
    return ConversionType.pdf;
  }

  // ==========================================================================
  // EXTENSION -> CONVERSION TYPE
  // ==========================================================================

  /// Resolves ConversionType from extension.
  static ConversionType fromExtension(
    String ext,
  ) {
    final cleanExt =
        ext
            .replaceAll('.', '')
            .trim()
            .toLowerCase();

    switch (cleanExt) {
      case 'docx':
      case 'doc':
        return ConversionType.docs;

      case 'pptx':
      case 'ppt':
        return ConversionType.ppt;

      case 'pdf':
      default:
        return ConversionType.pdf;
    }
  }

  // ==========================================================================
  // ID -> CONVERSION TYPE
  // ==========================================================================

  /// Resolves ConversionType from stored ID.
  static ConversionType fromId(
    String? id,
  ) {
    switch (id?.trim().toLowerCase()) {
      case 'docs':
      case 'doc':
      case 'docx':
      case 'word':
        return ConversionType.docs;

      case 'ppt':
      case 'pptx':
      case 'powerpoint':
        return ConversionType.ppt;

      case 'pdf':
      default:
        return ConversionType.pdf;
    }
  }
}