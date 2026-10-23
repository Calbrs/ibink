p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\phone_screen.dart"
s = open(p).read()
lines = s.split("\n")
for idx, line in enumerate(lines, 1):
    if "color: AuthColors.ink," in line:
        print(idx, repr(line))
PY