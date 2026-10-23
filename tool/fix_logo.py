p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\phone_screen.dart"
s = open(p).read()
old = """                          onPressed: c.isLoading ? null : c.signInWithGoogle,
                        ),
                      ),
                    ],
                  ],"""
new = """                          onPressed: c.isLoading ? null : c.signInWithGoogle,
                        ),
                      ),
                    ],

                    // ---------- Cromemos footer logo ----------
                    if (!keyboardOpen) ...[
                      const SizedBox(height: 24),
                      Center(
                        child: InkWell(
                          onTap: _openCromemos,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Image.asset(
                              'assets/icons/Cromemos Site logo.webp',
                              height: 20,
                              fit: BoxFit.contain,
                              semanticLabel: 'Cromemos',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],"""
assert old in s, "old not found"
s = s.replace(old, new, 1)
# add keyboardOpen variable back
s = s.replace(
    "    final c = widget.controller;\n\n    return Column(",
    "    final c = widget.controller;\n    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;\n\n    return Column(",
    1,
)
# add _openCromemos method back (before build)
s = s.replace(
    "  @override\n  Widget build(BuildContext context) {\n    final c = widget.controller;",
    "  Future<void> _openCromemos() async {}\n\n  @override\n  Widget build(BuildContext context) {\n    final c = widget.controller;",
    1,
)
open(p, "w").write(s)
print("done")
PY