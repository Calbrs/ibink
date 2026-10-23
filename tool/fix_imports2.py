# Fix splash_screen and _country_picker_dialog: add auth_screen import
files = [
 r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\splash_screen.dart",
 r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\_country_picker_dialog.dart",
]
for f in files:
    s = open(f).read()
    if "auth_screen.dart" not in s:
        lines = s.split("\n")
        idx = next(i for i, l in enumerate(lines) if l.startswith("class "))
        lines.insert(idx, "import 'auth_screen.dart';")
        s = "\n".join(lines)
        open(f, "w").write(s)

# Fix auth_screen: add dart:async import
p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\auth_screen.dart"
s = open(p).read()
if "import 'dart:async';" not in s:
    s = s.replace("import 'package:flutter/material.dart';",
                  "import 'dart:async';\nimport 'package:flutter/material.dart';", 1)
    open(p, "w").write(s)
print("done")
PY