import 'package:flutter/material.dart';

enum ConversionType {
  pdf(
    id: 'pdf',
    label: 'PDF Document',
    shortName: 'PDF',
    extension: 'pdf',
    mimeType: 'application/pdf',
    icon: Icons.picture_as_pdf_rounded,
    badgeColor: Color(0xFFE53935),
    gradientStart: Color(0xFF007A5E),
    gradientEnd: Color(0xFF00A77E),
  ),
  docs(
    id: 'docs',
    label: 'Word Document',
    shortName: 'DOCS',
    extension: 'docx',
    mimeType:
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    icon: Icons.article_rounded,
    badgeColor: Color(0xFF1E88E5),
    gradientStart: Color(0xFF1565C0),
    gradientEnd: Color(0xFF42A5F5),
  ),
  ppt(
    id: 'ppt',
    label: 'PowerPoint Presentation',
    shortName: 'PPT',
    extension: 'pptx',
    mimeType:
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    icon: Icons.slideshow_rounded,
    badgeColor: Color(0xFFE65100),
    gradientStart: Color(0xFFD84315),
    gradientEnd: Color(0xFFFF7043),
  );

  final String id;
  final String label;
  final String shortName;
  final String extension;
  final String mimeType;
  final IconData icon;
  final Color badgeColor;
  final Color gradientStart;
  final Color gradientEnd;

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

  /// Resolves ConversionType from a file name or file path
  static ConversionType fromFileName(String fileName) {
    final lower = fileName.trim().toLowerCase();
    if (lower.endsWith('.docx') || lower.endsWith('.doc')) {
      return ConversionType.docs;
    } else if (lower.endsWith('.pptx') || lower.endsWith('.ppt')) {
      return ConversionType.ppt;
    }
    return ConversionType.pdf;
  }

  /// Resolves ConversionType from extension string
  static ConversionType fromExtension(String ext) {
    final cleanExt = ext.replaceAll('.', '').trim().toLowerCase();
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

  /// Resolves ConversionType from id
  static ConversionType fromId(String? id) {
    switch (id?.toLowerCase()) {
      case 'docs':
      case 'docx':
        return ConversionType.docs;
      case 'ppt':
      case 'pptx':
        return ConversionType.ppt;
      case 'pdf':
      default:
        return ConversionType.pdf;
    }
  }
}
