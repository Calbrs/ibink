import re
p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\auth_screen.dart"
s = open(p).read()
# Remove Expanded( + child: Center( + child: AnimatedSwitcher( -> AnimatedSwitcher(
s = re.sub(r"Expanded\(\s*child:\s*Center\(\s*child:\s*AnimatedSwitcher\(", "AnimatedSwitcher(", s, count=1)
# Remove the two extra closing parens before the final ],
s = re.sub(r"child: _currentStep\(\),\s*\),\s*\),\s*\),\s*\],", "child: _currentStep(),\n                                ),\n                            ],", s, count=1)
# Set mainAxisAlignment to center
s = s.replace("mainAxisAlignment: MainAxisAlignment.spaceBetween,", "mainAxisAlignment: MainAxisAlignment.center,")
open(p, "w").write(s)
print("done")
PY