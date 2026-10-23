p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\auth_screen.dart"
s = open(p).read()
i = s.find("AuthBrandRow()")
print(repr(s[i-80:i+60]))