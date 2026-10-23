p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\phone_screen.dart"
s = open(p).read()
idx = 0
while True:
    i = s.find("AuthColors.ink", idx)
    if i < 0: break
    print(i, repr(s[max(0,i-40):i+40]))
    idx = i+1
PY