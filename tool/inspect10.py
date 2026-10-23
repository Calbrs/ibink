p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\phone_screen.dart"
s = open(p).read()
print("ink count:", s.count("AuthColors.ink"))
print("inkFaint count:", s.count("AuthColors.inkFaint"))
import re
for m in re.finditer(r"color: AuthColors\.\w+", s):
    print(m.group(0))
PY