class AppConstants {
  // App Info
  static const String appName = 'DocVault';
  static const String appTagline = 'Your Documents. Secured.';

  // Common strings
  static const String createPdf = 'Create PDF';
  static const String camera = 'Camera';
  static const String gallery = 'Gallery';
  static const String review = 'Review';
  static const String generatePdf = 'Generate PDF';
  static const String open = 'Open';
  static const String share = 'Share';
  static const String remove = 'Remove';
  static const String addMore = 'Add More';
  static const String reorder = 'Reorder';
  static const String done = 'Done';
  static const String cancel = 'Cancel';

  // Error messages
  static const String cameraPermissionDenied =
      'Camera permission denied. Please enable it in settings to capture documents.';
  static const String cameraInitFailed =
      'Failed to initialize camera. Please try using Gallery instead.';
  static const String noCameraAvailable = 'No camera available on this device.';
  static const String noImagesSelected =
      'Please select at least one image to generate PDF.';
  static const String pdfGenerationFailed =
      'Failed to generate PDF. Please try again.';
  static const String pdfSaveFailed = 'Failed to save PDF. Please try again.';
  static const String noViewerAvailable =
      'No PDF viewer available on this device.';

  // Success messages
  static const String pdfGeneratedSuccessfully = 'PDF generated successfully!';
}
