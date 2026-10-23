p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\phone_screen.dart"
s = open(p).read()
i = s.find("AuthGlyphType.chevronDown")
print(repr(s[i-60:i+80]))
PY