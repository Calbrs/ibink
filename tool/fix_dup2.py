p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\auth_screen.dart"
s = open(p).read()
old = "import 'package:world_code_picker/country_code_picker.dart';\nimport 'package:go_router/go_router.dart';\nimport 'package:world_code_picker/country_code_picker.dart';\n"
new = "import 'package:world_code_picker/country_code_picker.dart';\nimport 'package:go_router/go_router.dart';\n"
assert old in s, "old not found"
s = s.replace(old, new, 1)
open(p, "w").write(s)
print("done")
PY