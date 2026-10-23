files = [
 r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\phone_screen.dart",
 r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\otp_screen.dart",
 r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\shop_screen.dart",
 r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\splash_screen.dart",
 r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\_country_picker_dialog.dart",
]
for f in files:
    s = open(f).read()
    s = s.replace("import 'auth_controller.dart';\n", "import 'auth_screen.dart';\n")
    s = s.replace("import 'auth_kit.dart';\n", "")
    open(f, "w").write(s)
print("done")
PY