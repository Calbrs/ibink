p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\phone_screen.dart"
s = open(p).read()

# hint color -> black (ink)
s = s.replace("color: AuthColors.inkFaint,", "color: AuthColors.ink,", 1)

# apple icon -> white (paper)
old_apple = """                  'assets/icons/apple.png',
                  width: 20,
                  height: 20,
                  color: AuthColors.gold,"""
new_apple = """                  'assets/icons/apple.png',
                  width: 20,
                  height: 20,
                  color: AuthColors.paper,"""
assert old_apple in s, "apple not found"
s = s.replace(old_apple, new_apple, 1)

# google icon -> white (paper)
old_google = """                  'assets/icons/google.png',
                  width: 20,
                  height: 20,
                  color: AuthColors.gold,"""
new_google = """                  'assets/icons/google.png',
                  width: 20,
                  height: 20,
                  color: AuthColors.paper,"""
assert old_google in s, "google not found"
s = s.replace(old_google, new_google, 1)

open(p, "w").write(s)
print("done")
PY