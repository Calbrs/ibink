import re
p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\auth_screen.dart"
s = open(p).read()
s = s.replace("                              Expanded(\n                              child: Center(\n                                child: AnimatedSwitcher(", "                              AnimatedSwitcher(")
# fix closing: remove one extra ), from the Expanded/Center wrapper
s = re.sub(r"                                  child: _currentStep\(\),\n                                \),\n                              \),\n                            \],", "                                  child: _currentStep(),\n                                ),\n                            ],", s, count=1)
# add mainAxisAlignment center to the Column
s = s.replace("                            crossAxisAlignment: CrossAxisAlignment.stretch,\n                            children: [\n                              const Align(\n                                alignment: Alignment.centerLeft,\n                                child: AuthBrandRow(),", "                            crossAxisAlignment: CrossAxisAlignment.stretch,\n                            mainAxisAlignment: MainAxisAlignment.center,\n                            children: [\n                              const Align(\n                                alignment: Alignment.centerLeft,\n                                child: AuthBrandRow(),")
open(p, "w").write(s)
print("done")
PY