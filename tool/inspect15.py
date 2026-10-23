p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\phone_screen.dart"
s = open(p).read()
i = s.find("cursorColor: AuthColors.gold")
print(repr(s[i-20:i+120]))