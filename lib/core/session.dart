import 'package:shared_preferences/shared_preferences.dart';
import 'app_logger.dart';
import 'api_client.dart';
import 'api_config.dart';

const String _tag = 'Session';

class Session {
  Session._();
  static final Session instance = Session._();

  static const String _keyToken = 'auth_token';
  static const String _keyPhoneToken = 'phone_token';
  static const String _keyPhone = 'phone_number';
  static const String _keyUserId = 'user_id';
  static const String _keyIsRegistered = 'is_registered';
  static const String _keyRoleId = 'role_id';
  static const String _keyRole = 'role';
  static const String _keyShopName = 'shop_name';
  static const String _keyShopSlug = 'shop_slug';
  static const String _keyBusinessType = 'business_type';
  static const String _keyLocationRegion = 'location_region';
  static const String _keyStoreDistrict = 'store_district';
  static const String _keyStoreDescription = 'store_description';
  static const String _keySellerStatus = 'seller_status';
  static const String _keyCreatedAt = 'created_at';
  static const String _keyShippingRegion = 'shipping_region';
  static const String _keyShippingDistrict = 'shipping_district';
  static const String _keyShippingAddress = 'shipping_address';

  String? _token;
  String? _phoneToken;
  String? _phone;
  int? _userId;
  bool _isRegistered = false;
  int? _roleId;
  String? _role;
  String? _shopName;
  String? _shopSlug;
  String? _businessType;
  String? _locationRegion;
  String? _storeDistrict;
  String? _storeDescription;
  String? _sellerStatus;
  String? _createdAt;
  String? _shippingRegion;
  String? _shippingDistrict;
  String? _shippingAddress;

  String? get token => _token;
  String? get phoneToken => _phoneToken;
  String? get phone => _phone;
  int? get userId => _userId;
  bool get isRegistered => _isRegistered;
  int? get roleId => _roleId;
  String? get role => _role;
  bool get isSeller => _role == 'seller';
  bool get isBuyer => _role == 'buyer';
  String? get shopName => _shopName;
  String? get shopSlug => _shopSlug;
  String? get businessType => _businessType;
  String? get locationRegion => _locationRegion;
  String? get storeDistrict => _storeDistrict;
  String? get storeDescription => _storeDescription;
  String? get sellerStatus => _sellerStatus;
  String? get createdAt => _createdAt;
  String? get shippingRegion => _shippingRegion;
  String? get shippingDistrict => _shippingDistrict;
  String? get shippingAddress => _shippingAddress;

  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_keyToken);
    _phoneToken = prefs.getString(_keyPhoneToken);
    _phone = prefs.getString(_keyPhone);
    _userId = prefs.getInt(_keyUserId);
    _isRegistered = prefs.getBool(_keyIsRegistered) ?? false;
    _roleId = prefs.getInt(_keyRoleId);
    _role = prefs.getString(_keyRole);
    _shopName = prefs.getString(_keyShopName);
    _shopSlug = prefs.getString(_keyShopSlug);
    _businessType = prefs.getString(_keyBusinessType);
    _locationRegion = prefs.getString(_keyLocationRegion);
    _storeDistrict = prefs.getString(_keyStoreDistrict);
    _storeDescription = prefs.getString(_keyStoreDescription);
    _sellerStatus = prefs.getString(_keySellerStatus);
    _createdAt = prefs.getString(_keyCreatedAt);
    _shippingRegion = prefs.getString(_keyShippingRegion);
    _shippingDistrict = prefs.getString(_keyShippingDistrict);
    _shippingAddress = prefs.getString(_keyShippingAddress);

    if (_token != null && _token!.isNotEmpty) {
      ApiClient.instance.setToken(_token!);
    }
    if (_phoneToken != null && _phoneToken!.isNotEmpty) {
      ApiClient.instance.setPhoneToken(_phoneToken!);
    }

    AppLogger.instance.info(
      _tag,
      'Session init: loggedIn=$isLoggedIn registered=$_isRegistered '
      'role=${_role ?? 'unknown'} userId=${_userId ?? 'none'}',
    );
  }

  Future<void> ensureTokenInApiClient() async {
    if (_token != null && _token!.isNotEmpty) {
      ApiClient.instance.setToken(_token!);
    }
    if (_phoneToken != null && _phoneToken!.isNotEmpty) {
      ApiClient.instance.setPhoneToken(_phoneToken!);
    }
  }

  /// Save login data – handles both existing and new user flows.
  /// The [data] map must contain at least `access_token`.
  /// `phone_token` is optional; if missing, it is ignored.
  Future<void> saveLogin(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    final newToken = data['access_token'] as String?;
    final newPhoneToken = data['phone_token'] as String?;
    final registered = data['is_registered'] == true;

    if (newToken != null && newToken.isNotEmpty) {
      _token = newToken;
      await prefs.setString(_keyToken, _token!);
      ApiClient.instance.setToken(_token!);
    }

    // Only set phone token if provided
    if (newPhoneToken != null && newPhoneToken.isNotEmpty) {
      _phoneToken = newPhoneToken;
      await prefs.setString(_keyPhoneToken, _phoneToken!);
      ApiClient.instance.setPhoneToken(_phoneToken!);
    } else {
      // Ensure phone token is cleared if not provided
      _phoneToken = null;
      await prefs.remove(_keyPhoneToken);
      ApiClient.instance.clearPhoneToken();
    }

    _isRegistered = registered;
    await prefs.setBool(_keyIsRegistered, _isRegistered);

    AppLogger.instance.info(
      _tag,
      'Login saved: registered=$registered role=${_role ?? 'unknown'} '
      'hasToken=${newToken?.isNotEmpty == true}',
    );

    await _applyProfileFields(data, prefs);

    // If no account_data, but we have phone_number, store it
    if (data['account_data'] == null) {
      final phoneNumber = data['phone_number'] as String?;
      if (phoneNumber != null) {
        _phone = phoneNumber;
        await prefs.setString(_keyPhone, _phone!);
      }
    }
  }

  Future<bool> refreshProfile() async {
    if (!isLoggedIn) return false;

    final res = await ApiClient.instance.get(ApiConfig.userProfileEndpoint);
    if (!res.success || res.data == null) {
      AppLogger.instance.warn(_tag, 'refreshProfile failed: ${res.error}');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    _isRegistered = res.data!['is_registered'] == true;
    await prefs.setBool(_keyIsRegistered, _isRegistered);

    await _applyProfileFields(res.data!, prefs);
    return true;
  }

  Future<void> _applyProfileFields(Map<String, dynamic> data, SharedPreferences prefs) async {
    final roleId = data['role_id'] as int?;
    final role = data['role'] as String?;

    if (roleId != null) {
      _roleId = roleId;
      await prefs.setInt(_keyRoleId, roleId);
    }
    if (role != null) {
      _role = role;
      await prefs.setString(_keyRole, role);
    }

    final accountData = data['account_data'] as Map<String, dynamic>?;
    if (accountData == null) return;

    final id = accountData['id'];
    if (id is int) {
      _userId = id;
      await prefs.setInt(_keyUserId, id);
    }

    if (role == 'seller') {
      final phone = accountData['seller_phone'] as String?;
      if (phone != null) {
        _phone = phone;
        await prefs.setString(_keyPhone, phone);
      }

      final storeName = accountData['store_name'] as String?;
      final storeSlug = accountData['store_slug'] as String?;
      if (storeName != null) {
        _shopName = storeName;
        await prefs.setString(_keyShopName, storeName);
      }
      if (storeSlug != null) {
        _shopSlug = storeSlug;
        await prefs.setString(_keyShopSlug, storeSlug);
      }

      final businessType = accountData['business_type'] as String?;
      final locationRegion = accountData['location_region'] as String?;
      final storeDistrict = accountData['store_district'] as String?;
      final storeDescription = accountData['store_description'] as String?;
      final sellerStatus = accountData['status'] as String?;
      final createdAt = accountData['created_at'] as String?;

      if (businessType != null) {
        _businessType = businessType;
        await prefs.setString(_keyBusinessType, businessType);
      }
      if (locationRegion != null) {
        _locationRegion = locationRegion;
        await prefs.setString(_keyLocationRegion, locationRegion);
      }
      if (storeDistrict != null) {
        _storeDistrict = storeDistrict;
        await prefs.setString(_keyStoreDistrict, storeDistrict);
      }
      if (storeDescription != null) {
        _storeDescription = storeDescription;
        await prefs.setString(_keyStoreDescription, storeDescription);
      }
      if (sellerStatus != null) {
        _sellerStatus = sellerStatus;
        await prefs.setString(_keySellerStatus, sellerStatus);
      }
      if (createdAt != null) {
        _createdAt = createdAt;
        await prefs.setString(_keyCreatedAt, createdAt);
      }
    } else if (role == 'buyer') {
      final phone = accountData['buyer_phone'] as String?;
      if (phone != null) {
        _phone = phone;
        await prefs.setString(_keyPhone, phone);
      }

      final region = accountData['shipping_region'] as String?;
      final district = accountData['shipping_district'] as String?;
      final address = accountData['shipping_address'] as String?;
      if (region != null) {
        _shippingRegion = region;
        await prefs.setString(_keyShippingRegion, region);
      }
      if (district != null) {
        _shippingDistrict = district;
        await prefs.setString(_keyShippingDistrict, district);
      }
      if (address != null) {
        _shippingAddress = address;
        await prefs.setString(_keyShippingAddress, address);
      }
    }
  }

  Future<void> saveShopDetails({required String shopName, required String shopSlug}) async {
    final prefs = await SharedPreferences.getInstance();
    _shopName = shopName;
    _shopSlug = shopSlug;
    _isRegistered = true;

    await prefs.setString(_keyShopName, shopName);
    await prefs.setString(_keyShopSlug, shopSlug);
    await prefs.setBool(_keyIsRegistered, true);
  }

  Future<void> setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    _isRegistered = value;
    await prefs.setBool(_keyIsRegistered, value);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyPhoneToken);
    await prefs.remove(_keyPhone);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyIsRegistered);
    await prefs.remove(_keyRoleId);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyShopName);
    await prefs.remove(_keyShopSlug);
    await prefs.remove(_keyBusinessType);
    await prefs.remove(_keyLocationRegion);
    await prefs.remove(_keyStoreDistrict);
    await prefs.remove(_keyStoreDescription);
    await prefs.remove(_keySellerStatus);
    await prefs.remove(_keyCreatedAt);
    await prefs.remove(_keyShippingRegion);
    await prefs.remove(_keyShippingDistrict);
    await prefs.remove(_keyShippingAddress);

    _token = null;
    _phoneToken = null;
    _phone = null;
    _userId = null;
    _isRegistered = false;
    _roleId = null;
    _role = null;
    _shopName = null;
    _shopSlug = null;
    _businessType = null;
    _locationRegion = null;
    _storeDistrict = null;
    _storeDescription = null;
    _sellerStatus = null;
    _createdAt = null;
    _shippingRegion = null;
    _shippingDistrict = null;
    _shippingAddress = null;

    ApiClient.instance.clearToken();
    AppLogger.instance.info(_tag, 'Logged out, all local session data cleared.');
  }

  Future<void> clear() async {
    await logout();
  }
}