p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\phone_screen.dart"
s = open(p).read()
i = s.find("cursorColor")
print(repr(s[i:i+60]) if i>=0 else "NOT FOUND")
print("count cursorColor:", s.count("cursorColor"))