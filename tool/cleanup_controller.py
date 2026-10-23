p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\auth_controller.dart"
s = open(p).read()

start = s.find("  // ------------------------------------------------------------\n  // 2b. SHOP PHONE VERIFICATION")
end = s.find("  void changePhoneNumber() {")
assert start != -1 and end != -1, "block not found"
s = s[:start] + s[end:]

import re
s = re.sub(
    r"  /// Return from the photo/verification step to the shop details form\.\n"
    r"  void backToShopDetails\(\) \{\n"
    r"    _timer\?\.cancel\(\);\n"
    r"    resendSeconds = 0;\n"
    r"    otpController\.clear\(\);\n"
    r"    otpAttempts = 0;\n"
    r"    shopCodeSent = false;\n"
    r"    errorMsg = null;\n"
    r"    step = AuthStep\.shopName;\n"
    r"    notifyListeners\(\);\n"
    r"  \}\n\n",
    "",
    s,
    count=1,
)

s = s.replace(
    "    businessType = null;\n    locationRegion = null;\n    shopCategory = null;\n    shopPhotoPath = null;\n    shopCodeSent = false;\n    notifyListeners();",
    "    businessType = null;\n    locationRegion = null;\n    notifyListeners();",
    1,
)

s = s.replace(
    "    if (shopCategory == null || shopCategory!.isEmpty) {\n      errorMsg = 'Choose a shop category.';\n      errorTick++;\n      return notifyListeners();\n    }\n\n",
    "",
    1,
)

s = s.replace("              'store_category': shopCategory,\n", "", 1)

open(p, "w").write(s)
print("done")
PY