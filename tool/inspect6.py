p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\phone_screen.dart"
s = open(p).read()
i = s.find("AuthFieldShell(")
print(repr(s[i:i+90]))