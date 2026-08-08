import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/theme.dart';
import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/session.dart';
import '../models/product_model.dart';
import '../widgets/resilient_image.dart';
import '../widgets/notification_modals.dart';
import '../widgets/app_shimmer.dart';
import '../widgets/barcode_scanner_sheet.dart';
import '../widgets/barcode_generator_dialog.dart';

class ProductFormScreen extends StatefulWidget {
  final ProductModel? product;
  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  static const double _imageHeight = 280;
  static const double _imageMargin = 2;
  static const int _maxImageBytes = 2 * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _categoryCtrl;

  String? _imagePath;
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
    _priceCtrl = TextEditingController(text: p != null ? p.price.toStringAsFixed(0) : '');
    _quantityCtrl = TextEditingController(text: p != null ? p.quantity.toString() : '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _categoryCtrl = TextEditingController(text: p?.category ?? '');

    if (p != null) {
      _imagePath = p.imagePath;
      _existingImageUrl = p.imageUrl;
      _scannedBarcode = p.barcode;
    }

    _debugSession();
  }

  void _debugSession() {
    final session = Session.instance;
    if (kDebugMode) {
      debugPrint('=== PRODUCT FORM DEBUG ===');
      debugPrint('isLoggedIn: ${session.isLoggedIn}');
      debugPrint('userId: ${session.userId}');
      debugPrint('role: ${session.role}');
      debugPrint('isSeller: ${session.isSeller}');
      debugPrint('token: ${session.token?.substring(0, session.token!.length > 20 ? 20 : session.token!.length)}...');
      debugPrint('isRegistered: ${session.isRegistered}');
      debugPrint('==========================');
    }
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

  String _sanitizeNumber(String input) => input.trim().replaceAll(RegExp(r'[,\s]'), '');

  Future<void> _showImageSourceSelector() async {
    showModalBottomSheet(useRootNavigator: true, context: context,
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
                  leading: const Icon(Icons.photo_library_rounded, color: AppColors.green),
                  title: const Text('Kutoka kwenye Matunzio (Gallery)'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndCropImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: AppColors.green),
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

    final boxWidth = MediaQuery.of(context).size.width - (_imageMargin * 2);
    const boxHeight = _imageHeight;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressQuality: 85,
      aspectRatio: CropAspectRatio(ratioX: boxWidth, ratioY: boxHeight),
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
        message: 'Picha uliyochagua inazidi 2MB. Tafadhali chagua picha ndogo zaidi.',
      );
      return;
    }

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

  String _friendlyErrorMessage(ApiResponse res) {
    if (res.fieldErrors != null && res.fieldErrors!.isNotEmpty) {
      final firstEntry = res.fieldErrors!.entries.first;
      if (firstEntry.value.isNotEmpty) {
        return firstEntry.value.first;
      }
    }
    return res.error ?? 'Imeshindwa kuhifadhi bidhaa. Tafadhali jaribu tena.';
  }

  Future<void> _save() async {
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

    if (kDebugMode) {
      final session = Session.instance;
      debugPrint('=== SAVING PRODUCT ===');
      debugPrint('UserId (local cache, si lazima): ${session.userId}');
      debugPrint('Has Token: ${ApiClient.instance.hasToken}');
      debugPrint('========================');
    }

    setState(() => _isSaving = true);

    try {
      final name = _nameCtrl.text.trim();
      final price = double.parse(_sanitizeNumber(_priceCtrl.text));
      final quantity = int.parse(_sanitizeNumber(_quantityCtrl.text));
      final description = _descCtrl.text.trim();
      final category = _categoryCtrl.text.trim();

      final fields = {
        'product_name': name,
        'price': price.toString(),
        'stock': quantity.toString(),
        'description': description,
        if (category.isNotEmpty) 'category': category,
        'barcode': _scannedBarcode ?? '',
        'status': widget.product?.status ?? 'active',
      };

      if (_isEditing) {
        if (kDebugMode) debugPrint('Updating product: ${widget.product!.id}');
        final response = await ApiClient.instance.putMultipart(
          '${ApiConfig.productsEndpoint}/${widget.product!.id}',
          fields,
          _imagePath,
          'image',
        );
        if (!mounted) return;
        if (response.success) {
          _handleSaveSuccess(response);
        } else {
          if (response.statusCode == 401) {
            if (!mounted) return;
            NotificationService.showError(
              context,
              title: 'Muda Umeisha',
              message: 'Kipindi chako kimeisha. Tafadhali ingia tena kwenye mfumo.',
            );
          } else {
            if (!mounted) return;
            NotificationService.showError(
              context,
              title: 'Imeshindwa Kusasisha',
              message: _friendlyErrorMessage(response),
            );
          }
        }
      } else {
        if (kDebugMode) debugPrint('Creating new product');
        final response = await ApiClient.instance.postMultipart(
          ApiConfig.productsEndpoint,
          fields,
          _imagePath,
          'image',
        );
        if (!mounted) return;
        if (response.success) {
          _handleSaveSuccess(response);
        } else {
          if (response.statusCode == 401) {
            if (!mounted) return;
            NotificationService.showError(
              context,
              title: 'Muda Umeisha',
              message: 'Kipindi chako kimeisha. Tafadhali ingia tena kwenye mfumo.',
            );
          } else {
            if (!mounted) return;
            NotificationService.showError(
              context,
              title: 'Imeshindwa Kuongeza',
              message: _friendlyErrorMessage(response),
            );
          }
        }
      }
    } on FormatException {
      if (!mounted) return;
      NotificationService.showError(
        context,
        title: 'Namba Isiyo Sahihi',
        message: 'Tafadhali hakikisha Bei na Idadi ya bidhaa zimejazwa kwa namba sahihi.',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving product: $e');
      if (!mounted) return;
      NotificationService.showError(
        context,
        title: 'Hitilafu ya Mtandao',
        message: 'Imeshindwa kuunganisha kwenye seva. Angalia intaneti yako na ujaribu tena.',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _handleSaveSuccess(ApiResponse<Map<String, dynamic>> response) {
    final raw = response.data?['data'] ?? response.data;
    if (raw == null || raw is! Map<String, dynamic> || raw['id'] == null) {
      if (!mounted) return;
      NotificationService.showError(
        context,
        title: 'Data Zisizokamilika',
        message: 'Ombi limetumwa lakini uthibitisho wa bidhaa haukupatikana kikamilifu. '
            'Tafadhali angalia orodha ya bidhaa upya.',
      );
      return;
    }

    final saved = ProductModel.fromJson(raw);

    // Mark save as successful FIRST so PopScope's canPop lets the
    // programmatic pop below through without showing the "unsaved
    // changes" confirmation modal.
    _saveSuccessful = true;

    if (!mounted) return;
    NotificationService.showSuccessBanner(
      context,
      title: 'Hongera!',
      message: _isEditing ? 'Bidhaa imesasishwa kikamilifu.' : 'Bidhaa imeongezwa kikamilifu.',
    );

    if (mounted) Navigator.of(context).pop(saved);
  }

  Future<void> _openFormScanner() async {
    // Omba ruhusa ya storage na kamera mapema
    await [
      Permission.camera,
      Permission.storage,
      Permission.photos,
    ].request();

    // Hatua 0: Chagua kati ya kuscan kimwili au kuzalisha picha mpya
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
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              const Text(
                'Barcode ya Bidhaa',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(10)),
                  child: Image.asset('assets/icons/barcode.png', width: 20, height: 20, color: AppColors.green),
                ),
                title: const Text('Scan Barcode ya Kimwili', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Tumia kamera kusoma barcode iliyopo kwenye bidhaa'),
                onTap: () => Navigator.pop(ctx, 'scan'),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.amber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.qr_code_2_rounded, color: AppColors.amber, size: 24),
                ),
                title: const Text('Tengeneza Barcode Mpya', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Zalisha na kudownload picha ya barcode kwa ajili ya bidhaa hii'),
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

    // Hatua 2: Angalia database — je barcode hii ipo tayari?
    // Onyesha loading spinner wakati tunasubiri jibu la server
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
      Navigator.of(context, rootNavigator: true).pop(); // Funga loading

      if (response.success && response.data != null) {
        // Chambua bidhaa zilizorudishwa na server
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

        // Filt kwa exact match ya barcode
        found = found.where((p) => p.barcode == barcode).toList();

        // Kama ni edit mode na barcode ipo kwenye bidhaa HIYOHIYO, ruhusiwa
        final isSameProduct = widget.product != null &&
            found.isNotEmpty &&
            found.first.id == widget.product!.id;

        if (found.isNotEmpty && !isSameProduct) {
          // ❌ Barcode ipo tayari kwenye bidhaa nyingine — kata!
          NotificationService.showError(
            context,
            title: 'Barcode Ipo Tayari',
            message: 'Barcode hii tayari imetumika na bidhaa "${found.first.name}". '
                'Kila bidhaa lazima iwe na barcode ya kipekee.',
          );
        } else {
          // ✅ Barcode haipo — hifadhi kama barcode ya bidhaa hii
          setState(() => _scannedBarcode = barcode);
          NotificationService.showSuccessBanner(
            context,
            title: 'Barcode Imerekodiwa',
            message: 'Barcode ya bidhaa: $barcode',
          );
        }
      } else {
        // Server imekataa au kuna tatizo — angalia kwa upole
        // (Hii inaweza kutokea kama backend haijasupport ?barcode= bado)
        // Katika hali hii, tunaruhusu kwani hatuna uhakika kama ipo au la
        setState(() => _scannedBarcode = barcode);
        NotificationService.showSuccessBanner(
          context,
          title: 'Barcode Imerekodiwa',
          message: 'Barcode ya bidhaa: $barcode',
        );
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Funga loading
      NotificationService.showError(
        context,
        title: 'Hitilafu ya Mtandao',
        message: 'Imeshindwa kuangalia barcode kwenye seva. Tafadhali jaribu tena.',
      );
    }
  }

  Widget _buildImageBox() {
    return GestureDetector(
      onTap: _onImageBoxTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(_imageMargin, 0, _imageMargin, 0),
        height: _imageHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            if (_hasAnyImage)
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: _hasAnyImage
            ? ResilientImage(
                imageUrl: _existingImageUrl,
                imagePath: _imagePath,
                width: double.infinity,
                height: _imageHeight,
                borderRadius: BorderRadius.circular(24),
                placeholderBackground: AppColors.greenSoft.withValues(alpha: 0.4),
                placeholderIcon: Icons.broken_image_outlined,
                placeholderIconSize: 40,
                placeholderIconColor: AppColors.green,
              )
            : Container(
                decoration: BoxDecoration(
                  color: AppColors.greenSoft.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.green.withValues(alpha: 0.12),
                              blurRadius: 12,
                            )
                          ],
                        ),
                        child: const Icon(Icons.add_photo_alternate_rounded, size: 32, color: AppColors.green),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Weka Picha ya Bidhaa',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.greenDeep),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gusa ili uchague picha au upige mpya',
                        style: TextStyle(fontSize: 11, color: AppColors.inkSoft.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

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
            message: 'Kuna mabadiliko ambayo hayajahifadhiwa kwenye fomu. Je, una uhakika unataka kuondoka?',
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
          body: Form(
            key: _formKey,
            child: Stack(
              children: [
                SafeArea(
                  top: false,
                  bottom: false,
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: [
                      SizedBox(height: topInset + _imageMargin),
                      _buildImageBox(),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader('JINA LA BIDHAA'),
                            Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: TextFormField(
                                    controller: _nameCtrl,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink),
                                    decoration: const InputDecoration(
                                      hintText: 'Mfano: Wireless Headphones',
                                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Jina linahitajika' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 1,
                                  child: GestureDetector(
                                    onTap: _openFormScanner,
                                    child: Container(
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: AppColors.panel,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.line),
                                      ),
                                      child: Center(
                                        child: Image.asset('assets/icons/barcode.png', width: 24, height: 24, color: AppColors.ink),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_scannedBarcode != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.qr_code_scanner_rounded, size: 14, color: AppColors.green),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Barcode ID: $_scannedBarcode',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.green),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Allow clearing the barcode
                                  GestureDetector(
                                    onTap: () => setState(() => _scannedBarcode = null),
                                    child: const Icon(Icons.cancel_rounded, size: 14, color: AppColors.inkFaint),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 24),

                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildSectionHeader('BEI (TSH)'),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _priceCtrl,
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.greenDeep),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                          hintText: '0',
                                          prefixText: 'TSh ',
                                          prefixStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.greenDeep),
                                        ),
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) return 'Bei inahitajika';
                                          if (double.tryParse(_sanitizeNumber(v)) == null) return 'Namba tu';
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildSectionHeader('IDADI (STOCK)'),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: _quantityCtrl,
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.ink),
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(hintText: '0'),
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) return 'Idadi inahitajika';
                                          if (int.tryParse(_sanitizeNumber(v)) == null) return 'Namba tu';
                                          return null;
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            _buildSectionHeader('KATEGORIA'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _categoryCtrl,
                              style: const TextStyle(fontSize: 15, color: AppColors.ink),
                              decoration: const InputDecoration(hintText: 'Mfano: Electronics'),
                            ),
                            const SizedBox(height: 24),

                            _buildSectionHeader('MAELEZO'),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _descCtrl,
                              maxLines: 4,
                              style: const TextStyle(fontSize: 14, color: AppColors.ink, height: 1.4),
                              decoration: const InputDecoration(
                                hintText: 'Andika maelezo ya bidhaa...',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Maelezo yanahitajika' : null,
                            ),
                            const SizedBox(height: 32),

                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _save,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.green,
                                  foregroundColor: AppColors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
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
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Positioned(
                  top: topInset + 8,
                  left: 12,
                  child: Material(
                    color: AppColors.white.withValues(alpha: 0.9),
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded, color: AppColors.green, size: 20),
                    ),
                  ),
                ),

                Positioned(
                  top: topInset + 8,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _isEditing ? 'Hariri Bidhaa' : 'Bidhaa Mpya',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.greenDeep),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.inkFaint,
          letterSpacing: 0.7,
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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