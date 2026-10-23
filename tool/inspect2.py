p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\auth_screen.dart"
s = open(p).read()
needle = "children: [\n                              const Align("
i = s.find(needle)
print(repr(s[i:i+140]))