p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\splash_screen.dart"
s = open(p).read()

if "import 'package:flutter/services.dart';" not in s:
    s = s.replace(
        "import 'package:flutter/material.dart';\n",
        "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';\n",
        1,
    )

old = """  @override
  void initState() {
    super.initState();
    _checkAuth();
  }"""
new = """  static const _transparentStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  );

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(_transparentStyle);
    _checkAuth();
  }"""
assert old in s, "old not found"
s = s.replace(old, new, 1)

# wrap build body in AnnotatedRegion for safety
s = s.replace(
    "    return Scaffold(\n      backgroundColor: AuthColors.gold,",
    "    return AnnotatedRegion<SystemUiOverlayStyle>(\n      value: _transparentStyle,\n      child: Scaffold(\n        backgroundColor: AuthColors.gold,",
    1,
)
# close the AnnotatedRegion: the Scaffold's closing needs an extra )
# The build ends with: );\n  }\n}  -> need to add )
# Find the last '  }\n}' and add a closing paren before
idx = s.rfind("  }\n}")
# insert ')' before the '  }\n}'  (closing AnnotatedRegion)
s = s[:idx] + "      ),\n" + s[idx:]

open(p, "w").write(s)
print("done")
PY