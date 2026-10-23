p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\auth_screen.dart"
s = open(p).read()
old = """                            children: [
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: AuthBrandRow(),
                              ),
                              const SizedBox(height: 40),
                              Expanded(
                                child: Center(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 280),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeIn,
                                    layoutBuilder: (current, previous) => Stack(
                                      alignment: Alignment.topCenter,
                                      children: [...previous, ?current],
                                    ),
                                    transitionBuilder: (child, animation) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(0, 0.04),
                                            end: Offset.zero,
                                          ).animate(animation),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: _currentStep(),
                                  ),
                                ),
                              ),
                            ],"""
new = """                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: AuthBrandRow(),
                              ),
                              const SizedBox(height: 40),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 280),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeIn,
                                layoutBuilder: (current, previous) => Stack(
                                  alignment: Alignment.topCenter,
                                  children: [...previous, ?current],
                                ),
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.04),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                child: _currentStep(),
                              ),
                            ],"""
assert old in s, "old not found"
s = s.replace(old, new)
open(p, "w").write(s)
print("done")
PY