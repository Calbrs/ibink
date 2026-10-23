import re
p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\auth_screen.dart"
s = open(p).read()
s2 = re.sub(
    r"const SizedBox\(height: 40\),\n(\s+)AnimatedSwitcher\(",
    "const SizedBox(height: 40),\n\\1Expanded(\n\\1  child: Center(\n\\1    child: AnimatedSwitcher(",
    s,
    count=1,
)
# close: AnimatedSwitcher's child: _currentStep(), followed by ), ], 
s3 = re.sub(
    r"child: _currentStep\(\),\n(\s+)\),\n(\s+)\],",
    "child: _currentStep(),\n\\1),\n\\1),\n\\1),\n\\2],",
    s2,
    count=1,
)
# remove the now-redundant mainAxisAlignment line
s4 = s3.replace("                            mainAxisAlignment: MainAxisAlignment.spaceBetween,\n", "")
open(p, "w").write(s4)
print("changed" if s4 != s else "NO CHANGE")
PY