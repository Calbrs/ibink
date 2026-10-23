p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\phone_screen.dart"
s = open(p).read()
print("lines:", s.count(chr(10)))
i = s.find("_kControlHeight")
print(repr(s[max(0,i-60):i+40]))