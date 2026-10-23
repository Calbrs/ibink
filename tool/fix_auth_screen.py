old = open(r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\auth_screen.dart").read()
p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\auth_screen.dart"
s = open(p).read()
old_block = """                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            ],
                          ),"""
new_block = """                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
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
                            ],
                          ),"""
assert old_block in s, "old block not found"
s = s.replace(old_block, new_block)
open(p, "w").write(s)
print("done")
PY