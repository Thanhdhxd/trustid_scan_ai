import os
import re

lib_dir = r"e:\TTTN\trustid_scan_ai\lib"
colors = ['kBackgroundDark', 'kSurfaceDark', 'kPrimaryColor', 'kTextGray', 'kTextLight', 'kWarningColor', 'kErrorColor']

color_import = "import 'package:trustid_scan_ai/core/theme/app_colors.dart';\n"
dio_import = "import 'package:trustid_scan_ai/home/data/home_stats_repository.dart';\n"

for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if file.endswith(".dart"):
            path = os.path.join(root, file)
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()

            needs_color = any(re.search(r'\b' + c + r'\b', content) for c in colors)
            has_color_def = any(re.search(r'(const|final)\s+Color\s+' + c, content) for c in colors)
            needs_dio = re.search(r'\bdioProvider\b', content) is not None
            has_dio_def = re.search(r'(const|final)\s+dioProvider\s*=', content) is not None

            lines = content.splitlines()
            imports = [i for i, line in enumerate(lines) if line.startswith("import ")]
            if not imports:
                continue
            
            last_import_idx = imports[-1]
            changed = False
            
            if needs_color and not has_color_def and "app_colors.dart" not in content:
                lines.insert(last_import_idx + 1, color_import.strip())
                last_import_idx += 1
                changed = True
                
            if needs_dio and not has_dio_def and "home_stats_repository.dart" not in content:
                lines.insert(last_import_idx + 1, dio_import.strip())
                last_import_idx += 1
                changed = True
                
            if changed:
                with open(path, "w", encoding="utf-8") as f:
                    f.write('\n'.join(lines) + '\n')
                print(f"Updated {path}")
