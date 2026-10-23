p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\phone_screen.dart"
s = open(p).read()
i = s.find("signInWithGoogle")
print(repr(s[i-200:i+120]))
PY