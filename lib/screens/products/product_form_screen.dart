import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../core/app_logger.dart';
import '../../core/session.dart';
import '../../core/tiktok_settings_service.dart';
import '../../models/product_model.dart';
import '../../widgets/resilient_image.dart';
import '../../widgets/notification_modals.dart';
import '../../widgets/app_shimmer.dart';
import '../../widgets/barcode_scanner_sheet.dart';
import '../../widgets/barcode_generator_dialog.dart';

class ProductFormScreen extends StatefulWidget {
  final ProductModel? product;
  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  static const String _tag = 'ProductForm';
  static const int _maxImageBytes = 2 * 1024 * 1024;
  static const int _tiktokTitleLimit = 90;

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _descCtrl;

  // Kept so `_isFormDirty` and `_save` don't need structural changes, but the
  // field is no longer rendered — category is always empty for new products.
  late final TextEditingController _categoryCtrl;

  String? _imagePath;

  /// Which socials the seller has selected to publish to.
  /// Only TikTok is available for now, and it defaults to off.
  bool _shareToTikTok = false;

  String? _existingImageUrl;
  String? _scannedBarcode;
  bool _isSaving = false;
  bool _saveSuccessful = false;

  bool get _isEditing => widget.product != null;

  bool get _isFormDirty {
    final p = widget.product;
    final originalName = p?.name ?? '';
    final originalPrice = p != null ? p.price.toStringAsFixed(0) : '';
    final originalQuantity = p != null ? p.quantity.toString() : '';
    final originalDesc = p?.description ?? '';
    final originalCategory = p?.category ?? '';
    final originalImagePath = p?.imagePath;
    final originalBarcode = p?.barcode;

    return _nameCtrl.text.trim() != originalName ||
        _sanitizeNumber(_priceCtrl.text) != originalPrice ||
        _sanitizeNumber(_quantityCtrl.text) != originalQuantity ||
        _descCtrl.text.trim() != originalDesc ||
        _categoryCtrl.text.trim() != originalCategory ||
        _imagePath != originalImagePath ||
        _scannedBarcode != originalBarcode;
  }

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _priceCtrl = TextEditingController(
        text: p != null ? p.price.toStringAsFixed(0) : '');
    _quantityCtrl =
        TextEditingController(text: p != null ? p.quantity.toString() : '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _categoryCtrl = TextEditingController(text: p?.category ?? '');

    if (p != null) {
      _imagePath = p.imagePath;
      _existingImageUrl = p.imageUrl;
      _scannedBarcode = p.barcode;
    }

    _logSession();
  }

  void _logSession() {
    final session = Session.instance;
    AppLogger.instance.info(
      _tag,
      'Product form opened — loggedIn=${session.isLoggedIn} '
      'userId=${session.userId ?? 'none'} role=${session.role ?? 'unknown'} '
      'isSeller=${session.isSeller} isRegistered=${session.isRegistered} '
      'hasToken=${session.token != null && session.token!.isNotEmpty}',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _quantityCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  String _sanitizeNumber(String input) =>
      input.trim().replaceAll(RegExp(r'[,\s]'), '');

  // ═══════════════════════════════════════════════════════════════════════
  // Image handling
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _showImageSourceSelector() async {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.inkFaint.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Chagua Chanzo cha Picha',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded,
                      color: AppColors.green),
                  title: const Text('Kutoka kwenye Matunzio (Gallery)'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndCropImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded,
                      color: AppColors.green),
                  title: const Text('Piga Picha Sasa (Camera)'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndCropImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndCropImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;
    if (!mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressQuality: 85,
      aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 10),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Panga Picha',
          toolbarColor: AppColors.green,
          toolbarWidgetColor: AppColors.white,
          activeControlsWidgetColor: AppColors.green,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: true,
          hideBottomControls: true,
        ),
        IOSUiSettings(
          title: 'Panga Picha',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
        ),
      ],
    );

    if (cropped == null) return;

    final fileSize = await File(cropped.path).length();
    if (fileSize > _maxImageBytes) {
      if (!mounted) return;
      NotificationService.showError(
        context,
        title: 'Picha ni Kubwa',
        message:
            'Picha uliyochagua inazidi 2MB. Tafadhali chagua picha ndogo zaidi.',
      );
      return;
    }

    if (!mounted) return;
    setState(() => _imagePath = cropped.path);
  }

  void _openFullImageView() {
    if (!_hasAnyImage) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) => _FullImageViewer(
          imagePath: _imagePath,
          networkImageUrl: _imagePath == null ? _existingImageUrl : null,
          onChangePhoto: () {
            Navigator.of(context).pop();
            _showImageSourceSelector();
          },
        ),
      ),
    );
  }

  bool get _hasAnyImage => _imagePath != null || _existingImageUrl != null;

  void _onImageBoxTap() {
    if (!_hasAnyImage) {
      _showImageSourceSelector();
    } else {
      _openFullImageView();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Save
  // ═══════════════════════════════════════════════════════════════════════

  String _friendlyErrorMessage(ApiResponse res) {
    if (res.fieldErrors != null && res.fieldErrors!.isNotEmpty) {
      final firstEntry = res.fieldErrors!.entries.first;
      if (firstEntry.value.isNotEmpty) return firstEntry.value.first;
    }
    return res.error ?? 'Imeshindwa kuhifadhi bidhaa. Tafadhali jaribu tena.';
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    ApiClient.instance.ensureTokenIsSet();

    if (!ApiClient.instance.hasToken) {
      if (!mounted) return;
      NotificationService.showError(
        context,
        title: 'Muda Umeisha',
        message: 'Tafadhali ingia tena kwenye akaunti yako. Token haipatikani.',
      );
      return;
    }

    AppLogger.instance.info(
      _tag,
      'Saving product — editing=$_isEditing '
      'id=${widget.product?.id ?? 'new'} cachedUserId=${Session.instance.userId ?? 'none'}',
    );

    setState(() => _isSaving = true);

    try {
      final name = _nameCtrl.text.trim();
      final price = double.parse(_sanitizeNumber(_priceCtrl.text));
      final quantity = int.parse(_sanitizeNumber(_quantityCtrl.text));
      final description = _descCtrl.text.trim();
      final category = _categoryCtrl.text.trim();

      final productFields = <String, String>{
        'product_name': name,
        'price': price.toString(),
        'stock': quantity.toString(),
        'description': description,
        if (category.isNotEmpty) 'category': category,
        'barcode': _scannedBarcode ?? '',
        'status': widget.product?.status ?? 'active',
      };

      if (_isEditing) {
        AppLogger.instance.info(_tag, 'Updating product: ${widget.product!.id}');
        final response = await ApiClient.instance.putMultipart(
          '${ApiConfig.productsEndpoint}/${widget.product!.id}',
          productFields,
          _imagePath,
          'image',
        );
        if (!mounted) return;
        if (response.success) {
          _handleSaveSuccess(response);
        } else if (response.statusCode == 401) {
          NotificationService.showError(
            context,
            title: 'Muda Umeisha',
            message:
                'Kipindi chako kimeisha. Tafadhali ingia tena kwenye mfumo.',
          );
        } else {
          NotificationService.showError(
            context,
            title: 'Imeshindwa Kusasisha',
            message: _friendlyErrorMessage(response),
          );
        }
      } else {
        AppLogger.instance.info(
          _tag,
          'Creating new product via /distribute, shareToTikTok=$_shareToTikTok',
        );

        // The seller's saved TikTok configuration, already clamped to what the
        // account permits by TikTokSettingsService.
        final settings = TikTokSettingsService.instance.settings;

        final fields = <String, String>{
          ...productFields,
          'platforms[]': 'tiktok',
          if (_shareToTikTok) ...{
            'tiktok_mode': settings.mode.name,
            'tiktok_post_image': '1',
            'tiktok_title': _titleForTikTok(name),
            'tiktok_description': description,
            'tiktok_privacy_level': settings.privacyLevel,
            'tiktok_disable_comment': '${!settings.allowComments}',
            'tiktok_disable_duet': '${!settings.allowDuet}',
            'tiktok_disable_stitch': '${!settings.allowStitch}',
            'tiktok_brand_organic_toggle': 'true',
            'tiktok_brand_content_toggle': 'false',
            'tiktok_is_aigc': '${settings.isAigc}',
          },
        };

        final response = await ApiClient.instance.postMultipart(
          ApiConfig.distributeEndpoint,
          fields,
          _imagePath,
          'image',
        );
        if (!mounted) return;
        if (response.success) {
          _handleDistributeSuccess(response);
        } else if (response.statusCode == 401) {
          NotificationService.showError(
            context,
            title: 'Muda Umeisha',
            message:
                'Kipindi chako kimeisha. Tafadhali ingia tena kwenye mfumo.',
          );
        } else if (response.statusCode == 422) {
          NotificationService.showError(
            context,
            title: 'Taarifa Zisizo Sahihi',
            message: _friendlyErrorMessage(response),
          );
        } else {
          NotificationService.showError(
            context,
            title: 'Imeshindwa Kuongeza',
            message: _friendlyErrorMessage(response),
          );
        }
      }
    } on FormatException {
      if (!mounted) return;
      NotificationService.showError(
        context,
        title: 'Namba Isiyo Sahihi',
        message:
            'Tafadhali hakikisha Bei na Idadi ya bidhaa zimejazwa kwa namba sahihi.',
      );
    } catch (e, st) {
      AppLogger.instance.error(_tag, 'Error saving product', e, st);
      if (!mounted) return;
      NotificationService.showError(
        context,
        title: 'Hitilafu ya Mtandao',
        message:
            'Imeshindwa kuunganisha kwenye seva. Angalia intaneti yako na ujaribu tena.',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _handleDistributeSuccess(ApiResponse<Map<String, dynamic>> response) {
    final raw = response.data?['product'] ?? response.data?['data'];
    if (raw is! Map<String, dynamic> || raw['id'] == null) {
      if (!mounted) return;
      NotificationService.showError(
        context,
        title: 'Data Zisizokamilika',
        message: 'Ombi limetumwa lakini uthibitisho wa bidhaa haukupatikana '
            'kikamilifu. Tafadhali angalia orodha ya bidhaa upya.',
      );
      return;
    }

    final saved = ProductModel.fromJson(raw);
    final status = response.data?['status'] as String?;

    final distribution = response.data?['distribution'];
    final tiktok =
        distribution is Map<String, dynamic> ? distribution['tiktok'] : null;
    final tiktokMap = tiktok is Map<String, dynamic> ? tiktok : null;
    final tiktokError = tiktokMap?['error'] as String?;

    AppLogger.instance.info(
      _tag,
      'Distributed product ${saved.id}, status=$status, '
      'http=${response.statusCode}, tiktokOk=${tiktokMap?['ok']}',
    );

    _saveSuccessful = true;

    if (!mounted) return;

    NotificationService.showSuccessBanner(
      context,
      title: 'Hongera!',
      message: 'Bidhaa imeongezwa kikamilifu.',
    );

    if (status == 'partial') {
      final reason = tiktokError ?? 'usambazaji';
      AppLogger.instance.warn(_tag, 'Distribution partial: $reason');
      NotificationService.showWarningBanner(
        context,
        message: 'Bidhaa imeongezwa, lakini usambazaji wa TikTok '
            'umeshindwa ($reason).',
      );
    }

    if (mounted) Navigator.of(context).pop(saved);
  }

  void _handleSaveSuccess(ApiResponse<Map<String, dynamic>> response) {
    final raw = response.data?['data'] ?? response.data;
    if (raw == null || raw is! Map<String, dynamic> || raw['id'] == null) {
      if (!mounted) return;
      NotificationService.showError(
        context,
        title: 'Data Zisizokamilika',
        message: 'Ombi limetumwa lakini uthibitisho wa bidhaa haukupatikana '
            'kikamilifu. Tafadhali angalia orodha ya bidhaa upya.',
      );
      return;
    }

    final saved = ProductModel.fromJson(raw);
    _saveSuccessful = true;

    if (!mounted) return;
    NotificationService.showSuccessBanner(
      context,
      title: 'Hongera!',
      message: _isEditing
          ? 'Bidhaa imesasishwa kikamilifu.'
          : 'Bidhaa imeongezwa kikamilifu.',
    );

    if (mounted) Navigator.of(context).pop(saved);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Barcode
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _openFormScanner() async {
    FocusScope.of(context).unfocus();

    await [
      Permission.camera,
      Permission.storage,
      Permission.photos,
    ].request();

    if (!mounted) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Barcode ya Bidhaa',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.greenSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Image.asset('assets/icons/barcode.png',
                      width: 20, height: 20, color: AppColors.green),
                ),
                title: const Text('Scan Barcode ya Kimwili',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text(
                    'Tumia kamera kusoma barcode iliyopo kwenye bidhaa'),
                onTap: () => Navigator.pop(ctx, 'scan'),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.qr_code_2_rounded,
                      color: AppColors.amber, size: 24),
                ),
                title: const Text('Tengeneza Barcode Mpya',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text(
                    'Zalisha na kudownload picha ya barcode kwa ajili ya bidhaa hii'),
                onTap: () => Navigator.pop(ctx, 'generate'),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice == null || !mounted) return;

    String? barcode;

    if (choice == 'generate') {
      barcode = await showModalBottomSheet<String>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const BarcodeGeneratorDialog(),
      );
    } else if (choice == 'scan') {
      barcode = await showModalBottomSheet<String>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const BarcodeScannerSheet(),
      );
    }

    if (barcode == null || !mounted) return;

    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.green),
      ),
    );

    try {
      final response = await ApiClient.instance
          .get('${ApiConfig.productsEndpoint}?barcode=$barcode');

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (response.success && response.data != null) {
        final payload = response.data?['data'] ?? response.data?['products'];
        List<ProductModel> found = [];

        if (payload is Map<String, dynamic> && payload['data'] is List) {
          found = (payload['data'] as List)
              .map((e) => ProductModel.fromJson(e))
              .toList();
        } else if (payload is List) {
          found = payload.map((e) => ProductModel.fromJson(e)).toList();
        } else if (payload is Map<String, dynamic> && payload['id'] != null) {
          found.add(ProductModel.fromJson(payload));
        }

        found = found.where((p) => p.barcode == barcode).toList();

        final isSameProduct = widget.product != null &&
            found.isNotEmpty &&
            found.first.id == widget.product!.id;

        if (found.isNotEmpty && !isSameProduct) {
          NotificationService.showError(
            context,
            title: 'Barcode Ipo Tayari',
            message:
                'Barcode hii tayari imetumika na bidhaa "${found.first.name}". '
                'Kila bidhaa lazima iwe na barcode ya kipekee.',
          );
        } else {
          setState(() => _scannedBarcode = barcode);
          NotificationService.showSuccessBanner(
            context,
            title: 'Barcode Imerekodiwa',
            message: 'Barcode ya bidhaa: $barcode',
          );
        }
      } else {
        setState(() => _scannedBarcode = barcode);
        NotificationService.showSuccessBanner(
          context,
          title: 'Barcode Imerekodiwa',
          message: 'Barcode ya bidhaa: $barcode',
        );
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      NotificationService.showError(
        context,
        title: 'Hitilafu ya Mtandao',
        message: 'Imeshindwa kuangalia barcode kwenye seva. Tafadhali jaribu tena.',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TikTok helpers
  // ═══════════════════════════════════════════════════════════════════════

  /// TikTok caps a photo post's title at 90 UTF-16 code units, which is what
  /// Dart's `String.length` counts. A long product name would otherwise earn
  /// a 400 from TikTok and leave the seller with a saved product and no post.
  String _titleForTikTok(String productName) {
    if (productName.length <= _tiktokTitleLimit) return productName;
    return '${productName.substring(0, _tiktokTitleLimit - 1).trimRight()}…';
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════════════════

  OutlineInputBorder _border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  InputDecoration _fieldDecoration({String? hint, String? prefixText}) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      hintStyle: const TextStyle(fontSize: 14, color: AppColors.inkFaint),
      prefixStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.greenDeep,
      ),
      errorStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
      isDense: true,
      filled: true,
      fillColor: AppColors.panel,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: _border(AppColors.line),
      enabledBorder: _border(AppColors.line),
      focusedBorder: _border(AppColors.green, 1.5),
      errorBorder: _border(AppColors.danger),
      focusedErrorBorder: _border(AppColors.danger, 1.5),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.inkFaint,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      color: AppColors.bg,
      padding: EdgeInsets.only(
        top: topInset + 8,
        left: 6,
        right: 12,
        bottom: 12,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.ink, size: 22),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _isEditing ? 'Hariri Bidhaa' : 'Bidhaa Mpya',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.2,
              ),
            ),
          ),
          _buildSocialsButton(),
        ],
      ),
    );
  }

  /// The header pill: opens the Socials bottom sheet.
  /// Shows a dot when TikTok (or any social) is selected, so the seller sees
  /// at a glance that the product will be cross-posted.
  Widget _buildSocialsButton() {
    final hasSelection = _shareToTikTok;
    return Material(
      color: hasSelection ? AppColors.green : AppColors.panel,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _showSocialsSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasSelection ? AppColors.green : AppColors.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.share_rounded,
                size: 15,
                color: hasSelection ? AppColors.white : AppColors.ink,
              ),
              const SizedBox(width: 6),
              Text(
                'Socials',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: hasSelection ? AppColors.white : AppColors.ink,
                ),
              ),
              if (hasSelection) ...[
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Socials bottom sheet
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _showSocialsSheet() async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            void toggleTikTok() {
              setSheetState(() => _shareToTikTok = !_shareToTikTok);
              setState(() {}); // reflect change in the header pill
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Grab handle ──────────────────────────────────
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.line,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Title row ────────────────────────────────────
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Socials',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Chagua akaunti ambazo bidhaa itatumwa.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkSoft,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded,
                              color: AppColors.inkFaint),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    const Divider(color: AppColors.line, height: 1),

                    const SizedBox(height: 16),
                    const Text(
                      'AKAUNTI ZILIZOUNGANISHWA',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.inkFaint,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _buildAccountTile(
                      icon: Image.asset(
                        'assets/icons/tik-tok.png',
                        width: 22,
                        height: 22,
                      ),
                      name: 'TikTok',
                      subtitle: 'Imeunganishwa • Chapisha kama post ya picha',
                      selected: _shareToTikTok,
                      onTap: toggleTikTok,
                    ),

                    const SizedBox(height: 16),

                    // ── Footer hint ──────────────────────────────────
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 14, color: AppColors.inkFaint),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _shareToTikTok
                              // Show the saved configuration so the seller can
                              // tell at a glance what the post will use.
                              ? ListenableBuilder(
                                  listenable: TikTokSettingsService.instance,
                                  builder: (context, _) => Text(
                                    'Itachapishwa kama: '
                                    '${TikTokSettingsService.instance.settings.summary}.',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.inkSoft,
                                      height: 1.4,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Hakuna akaunti iliyochaguliwa. Bidhaa itahifadhiwa bila kuchapishwa.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.inkSoft,
                                    height: 1.4,
                                  ),
                                ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Maliza',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAccountTile({
    required Widget icon,
    required String name,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected
            ? AppColors.greenSoft.withValues(alpha: 0.55)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Center(child: icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.inkSoft,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.green : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: selected ? AppColors.green : AppColors.line,
                      width: 1.6,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          size: 15, color: AppColors.white)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Form pieces
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildImageCard() {
    return GestureDetector(
      onTap: _onImageBoxTap,
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.line),
          ),
          child: _hasAnyImage ? _buildImageFilled() : _buildImageEmpty(),
        ),
      ),
    );
  }

  Widget _buildImageFilled() {
    return Stack(
      fit: StackFit.expand,
      children: [
        ResilientImage(
          imageUrl: _existingImageUrl,
          imagePath: _imagePath,
          width: double.infinity,
          height: double.infinity,
          borderRadius: BorderRadius.zero,
          placeholderBackground: AppColors.greenSoft.withValues(alpha: 0.4),
          placeholderIcon: Icons.broken_image_outlined,
          placeholderIconSize: 40,
          placeholderIconColor: AppColors.green,
        ),
        // Floating chip over the photo: stays light so it reads on any image.
        Positioned(
          right: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_rounded, size: 13, color: AppColors.greenDeep),
                SizedBox(width: 6),
                Text(
                  'Badilisha',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.greenDeep,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageEmpty() {
    return Container(
      color: AppColors.greenSoft.withValues(alpha: 0.35),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.panel,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.line),
              ),
              child: const Icon(Icons.add_photo_alternate_rounded,
                  size: 28, color: AppColors.green),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ongeza Picha ya Bidhaa',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.greenDeep,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gusa kuchagua au kupiga picha',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.inkSoft.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarcodeButton() {
    return GestureDetector(
      onTap: _openFormScanner,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.greenSoft.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Image.asset(
            'assets/icons/barcode.png',
            width: 24,
            height: 24,
            color: AppColors.greenDeep,
          ),
        ),
      ),
    );
  }

  Widget _buildBarcodeChip() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.greenSoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.qr_code_rounded,
              size: 15, color: AppColors.greenDeep),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _scannedBarcode!,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.greenDeep,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _scannedBarcode = null),
            child: const Icon(Icons.close_rounded,
                size: 16, color: AppColors.greenDeep),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.green.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: AppShimmerSpinner(),
              )
            : Text(
                _isEditing ? 'Hifadhi Mabadiliko' : 'Ongeza Bidhaa',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: PopScope(
        canPop: !_isFormDirty || _saveSuccessful,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;

          final shouldPop = await NotificationService.showConfirmation(
            context,
            title: 'Ondoka Bila Kuhifadhi?',
            message: 'Kuna mabadiliko ambayo hayajahifadhiwa kwenye fomu. '
                'Je, una uhakika unataka kuondoka?',
            confirmText: 'Ndiyo, Ondoka',
            cancelText: 'Baki Hapa',
            isDestructive: true,
          );

          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.bg,
          resizeToAvoidBottomInset: true,
          body: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    children: [
                      _buildImageCard(),
                      const SizedBox(height: 24),

                      // ─── Name + barcode ───────────────────────────
                      _buildFieldLabel('JINA LA BIDHAA'),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _nameCtrl,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                              decoration: _fieldDecoration(
                                hint: 'Mfano: Wireless Headphones',
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Jina linahitajika'
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _buildBarcodeButton(),
                        ],
                      ),
                      if (_scannedBarcode != null) _buildBarcodeChip(),

                      const SizedBox(height: 20),

                      // ─── Price + quantity ──────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('BEI (TSH)'),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _priceCtrl,
                                  textInputAction: TextInputAction.next,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.greenDeep,
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.,\s]'),
                                    ),
                                  ],
                                  decoration: _fieldDecoration(
                                    hint: '0',
                                    prefixText: 'TSh ',
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Inahitajika';
                                    }
                                    final n =
                                        double.tryParse(_sanitizeNumber(v));
                                    if (n == null) return 'Namba tu';
                                    if (n <= 0) return 'Weka bei sahihi';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('IDADI (STOCK)'),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _quantityCtrl,
                                  textInputAction: TextInputAction.next,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: _fieldDecoration(hint: '0'),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Inahitajika';
                                    }
                                    if (int.tryParse(_sanitizeNumber(v)) ==
                                        null) {
                                      return 'Namba tu';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ─── Description ───────────────────────────────
                      _buildFieldLabel('MAELEZO'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.ink,
                          height: 1.45,
                        ),
                        decoration: _fieldDecoration(
                          hint: 'Andika maelezo ya bidhaa...',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Maelezo yanahitajika'
                            : null,
                      ),

                      const SizedBox(height: 28),

                      // ─── Save (inline, scrolls with content) ───────
                      _buildSaveButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FullImageViewer extends StatelessWidget {
  final String? imagePath;
  final String? networkImageUrl;
  final VoidCallback onChangePhoto;

  const _FullImageViewer({
    this.imagePath,
    this.networkImageUrl,
    required this.onChangePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: imagePath != null
                    ? Image.file(
                        File(imagePath!),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white54,
                          size: 64,
                        ),
                      )
                    : Image.network(
                        networkImageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white54,
                          size: 64,
                        ),
                      ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: SafeArea(
              child: Material(
                color: Colors.white.withValues(alpha: 0.15),
                shape: const CircleBorder(),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 28,
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: onChangePhoto,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Badilisha Picha'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}