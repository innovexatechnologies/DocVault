import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/utils/file_utils.dart';
import '../../models/pdf_result.dart';

class ResultScreen extends StatelessWidget {
  final PdfResult pdfResult;

  const ResultScreen({super.key, required this.pdfResult});

  Future<void> _openPdf() async {
    final result = await OpenFile.open(pdfResult.filePath);
    if (result.type == ResultType.noAppToOpen) {
      // Show error
      debugPrint('No PDF viewer available');
    }
  }

  Future<void> _sharePdf(BuildContext context) async {
    try {
      await Share.shareXFiles([
        XFile(pdfResult.filePath),
      ], text: 'Check out my document: ${pdfResult.fileName}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to share PDF'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _createNewPdf(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveHelper.isTablet(context);
    final responsivePadding = ResponsiveHelper.getResponsivePadding(context);
    final buttonHeight = ResponsiveHelper.getResponsiveButtonHeight(context);
    final titleFontSize = ResponsiveHelper.getResponsiveFontSize(
      context,
      mobileSize: 22,
      tabletSize: 26,
      desktopSize: 28,
    );
    final labelFontSize = ResponsiveHelper.getResponsiveFontSize(
      context,
      mobileSize: 11,
      tabletSize: 12,
      desktopSize: 13,
    );
    final valueFontSize = ResponsiveHelper.getResponsiveFontSize(
      context,
      mobileSize: 11,
      tabletSize: 12,
      desktopSize: 13,
    );
    final buttonLabelFontSize = ResponsiveHelper.getResponsiveFontSize(
      context,
      mobileSize: 14,
      tabletSize: 16,
      desktopSize: 18,
    );

    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: Scaffold(
        backgroundColor: AppTheme.bgLight,
        appBar: AppBar(
          title: const Text('PDF Generated'),
          backgroundColor: AppTheme.bgWhite,
          foregroundColor: AppTheme.textPrimary,
          elevation: 1,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(responsivePadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Success Icon
                Center(
                  child: Container(
                    width: isTablet ? 120 : 100,
                    height: isTablet ? 120 : 100,
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.picture_as_pdf,
                        size: isTablet ? 70 : 60,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: responsivePadding),
                // Title
                Text(
                  'PDF Ready!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: responsivePadding * 0.67),
                // File Details
                Container(
                  padding: EdgeInsets.all(responsivePadding * 0.67),
                  decoration: BoxDecoration(
                    color: AppTheme.bgWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'File Name:',
                            style: TextStyle(
                              fontSize: labelFontSize,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: responsivePadding * 0.33),
                          Expanded(
                            child: Text(
                              pdfResult.fileName,
                              style: TextStyle(
                                fontSize: valueFontSize,
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: responsivePadding * 0.5),
                      Row(
                        children: [
                          Text(
                            'Pages:',
                            style: TextStyle(
                              fontSize: labelFontSize,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: responsivePadding * 0.33),
                          Text(
                            '${pdfResult.pageCount}',
                            style: TextStyle(
                              fontSize: valueFontSize,
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: responsivePadding * 0.5),
                      Row(
                        children: [
                          Text(
                            'Generated:',
                            style: TextStyle(
                              fontSize: labelFontSize,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: responsivePadding * 0.33),
                          Expanded(
                            child: Text(
                              _formatDateTime(pdfResult.generatedAt),
                              style: TextStyle(
                                fontSize: valueFontSize,
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: responsivePadding * 1.67),
                // Action Buttons - Stack on mobile, side by side on tablet
                if (isTablet)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: buttonHeight,
                              child: ElevatedButton.icon(
                                onPressed: _openPdf,
                                icon: const Icon(Icons.open_in_new),
                                label: Text(
                                  AppConstants.open,
                                  style: TextStyle(
                                    fontSize: buttonLabelFontSize,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: responsivePadding * 0.5),
                          Expanded(
                            child: SizedBox(
                              height: buttonHeight,
                              child: OutlinedButton.icon(
                                onPressed: () => _sharePdf(context),
                                icon: const Icon(Icons.share),
                                label: Text(
                                  AppConstants.share,
                                  style: TextStyle(
                                    fontSize: buttonLabelFontSize,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: const BorderSide(
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: responsivePadding * 0.5),
                      SizedBox(
                        height: buttonHeight,
                        child: OutlinedButton.icon(
                          onPressed: () => _createNewPdf(context),
                          icon: const Icon(Icons.add),
                          label: Text(
                            'Create New PDF',
                            style: TextStyle(fontSize: buttonLabelFontSize),
                          ),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: const BorderSide(color: AppTheme.accentColor),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: buttonHeight,
                        child: ElevatedButton.icon(
                          onPressed: _openPdf,
                          icon: const Icon(Icons.open_in_new),
                          label: Text(
                            AppConstants.open,
                            style: TextStyle(fontSize: buttonLabelFontSize),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: responsivePadding * 0.5),
                      SizedBox(
                        height: buttonHeight,
                        child: OutlinedButton.icon(
                          onPressed: () => _sharePdf(context),
                          icon: const Icon(Icons.share),
                          label: Text(
                            AppConstants.share,
                            style: TextStyle(fontSize: buttonLabelFontSize),
                          ),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: const BorderSide(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: responsivePadding * 0.5),
                      SizedBox(
                        height: buttonHeight,
                        child: OutlinedButton.icon(
                          onPressed: () => _createNewPdf(context),
                          icon: const Icon(Icons.add),
                          label: Text(
                            'Create New PDF',
                            style: TextStyle(fontSize: buttonLabelFontSize),
                          ),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: const BorderSide(color: AppTheme.accentColor),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
