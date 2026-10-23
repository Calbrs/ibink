p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\auth_screen.dart"
s = open(p).read()
import re
i = s.find("child: Column(")
print(repr(s[i:i+200]))
PY