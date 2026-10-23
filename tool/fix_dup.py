p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\auth_screen.dart"
s = open(p).read()
s = s.replace(
    'import "package:world_code_picker/country_code_picker.dart";\n'
    'import "package:go_router/go_router.dart";\n'
    'import "package:world_code_picker/country_code_picker.dart";\n',
    'import "package:world_code_picker/country_code_picker.dart";\n'
    'import "package:go_router/go_router.dart";\n',
    1,
)
open(p, "w").write(s)
print("done")
PY