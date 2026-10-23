import re
p = r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\auth_screen.dart"
s = open(p).read()

# 1. Fix imports: remove auth_controller/auth_kit, add their deps
s = s.replace("import 'auth_controller.dart';\n", "")
s = s.replace("import 'auth_kit.dart';\n", "")
# add deps after the flutter import
s = s.replace(
    "import 'package:flutter/material.dart';\n",
    "import 'dart:math' as math;\n"
    "import 'package:flutter/material.dart';\n"
    "import 'package:world_code_picker/country_code_picker.dart';\n",
    1,
)
# add core imports after country_list import
s = s.replace(
    "import '../../core/country_list.dart';\n",
    "import '../../core/country_list.dart';\n"
    "import '../../core/api_client.dart';\n"
    "import '../../core/api_config.dart';\n"
    "import '../../core/app_logger.dart';\n"
    "import '../../core/session.dart';\n",
    1,
)

# 2. Append auth_controller.dart content (strip its imports)
ctrl = open(r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\auth_controller.dart").read()
# remove import block
ctrl_body = ctrl[ctrl.find("// Auth flow: constants + AuthController"):]
# 3. Append auth_kit.dart content (strip imports)
kit = open(r"D:\Calbrs Projects\Ibink.me\ibink\lib\screens\auth\auth_kit.dart").read()
kit_body = kit[kit.find("// Onbaio auth kit: palette"):]
# Actually auth_kit starts with imports then comment; find the comment
kit_idx = kit.find("// Onbaio auth kit:")
kit_body = kit[kit_idx:]

s = s.rstrip() + "\n\n" + ctrl_body + "\n\n" + kit_body + "\n"

open(p, "w").write(s)
print("done")
PY