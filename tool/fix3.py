p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\auth_screen.dart"
s = open(p).read()
s = s.replace("                            mainAxisAlignment: MainAxisAlignment.spaceBetween,\n", "")
open(p, "w").write(s)
print("done")
PY