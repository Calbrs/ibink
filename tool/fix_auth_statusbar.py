p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\auth_screen.dart"
s = open(p).read()

# add services import if missing
if "package:flutter/services.dart" not in s:
    s = s.replace(
        "import 'package:flutter/material.dart';\n",
        "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';\n",
        1,
    )

old = """  @override
  void initState() {
    super.initState();
    _c = AuthController("""
new = """  static const _transparentStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemStatusBarContrastEnforced: false,
  );

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(_transparentStyle);
    _c = AuthController("""
assert old in s, "old not found"
s = s.replace(old, new, 1)
open(p, "w").write(s)
print("done")
PY