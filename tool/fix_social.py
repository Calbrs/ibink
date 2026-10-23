p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\phone_screen.dart"
s = open(p).read()

old = """    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: SizedBox(
        height: _kControlHeight,
        child: Material(
          color: AuthColors.ink,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            splashColor: AuthColors.gold.withValues(alpha: 0.18),
            highlightColor: AuthColors.gold.withValues(alpha: 0.08),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                leading,
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                    color: AuthColors.gold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );"""

new = """    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: SizedBox(
        height: _kControlHeight,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white, width: 1.4),
          ),
          child: InkWell(
            onTap: onPressed,
            splashColor: Colors.white.withValues(alpha: 0.12),
            highlightColor: Colors.white.withValues(alpha: 0.06),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                leading,
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );"""

assert old in s, "social button block not found"
s = s.replace(old, new, 1)

s = s.replace("label: 'Apple',", "label: 'Continue with Apple',", 1)
s = s.replace("label: 'Google',", "label: 'Continue with Google',", 1)

old_google_icon = """                leading: Image.asset(
                  'assets/icons/google.png',
                  width: 20,
                  height: 20,
                  color: AuthColors.paper,
                ),"""
new_google_icon = """                leading: Image.asset(
                  'assets/icons/google.png',
                  width: 20,
                  height: 20,
                ),"""
assert old_google_icon in s, "google icon block not found"
s = s.replace(old_google_icon, new_google_icon, 1)

open(p, "w").write(s)
print("done")
PY