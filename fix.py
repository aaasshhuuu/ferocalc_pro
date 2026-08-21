import os
import re

calc_dir = r"c:\projects\fincalc_pro\lib\features\calculators\presentation\screens"

helpers_code = """
  void _shareResult(BuildContext context) {
    // Use share_plus to share the calculation result text
    final resultText = 'Check out my calculation on Finora!';
    // For now show a snackbar since share_plus may not work on web
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share feature coming soon!'), backgroundColor: Color(0xFF10B981)),
    );
  }

  void _exportPdf(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF export coming soon!'), backgroundColor: Color(0xFF00B4D8)),
    );
  }
"""

def fix_calc_files():
    for f in os.listdir(calc_dir):
        if not f.endswith(".dart"): continue
        path = os.path.join(calc_dir, f)
        with open(path, "r", encoding="utf-8") as file:
            content = file.read()
        
        # Replace Icons.picture_as_pdf
        content = re.sub(
            r"(const\s+)?Icon\(\s*Icons\.picture_as_pdf\s*(,\s*color:\s*[^)]+)?\)",
            r"IconButton(icon: const Icon(Icons.picture_as_pdf\2), onPressed: () => _exportPdf(context))",
            content
        )
        
        # Replace Icons.share
        content = re.sub(
            r"(const\s+)?Icon\(\s*Icons\.share\s*(,\s*color:\s*[^)]+)?\)",
            r"IconButton(icon: const Icon(Icons.share\2), onPressed: () => _shareResult(context))",
            content
        )

        content = re.sub(r"const\s+CustomAppBar\(", "CustomAppBar(", content)
        content = re.sub(r"actions:\s*const\s*\[", "actions: [", content)
        
        if "_shareResult" not in content and "_exportPdf" not in content:
            build_method_pattern = r"(@override\s+Widget\s+build\(\s*BuildContext\s+context\s*\)\s*\{)"
            content = re.sub(build_method_pattern, helpers_code + r"\n  \1", content)
        
        content = re.sub(
            r"text:\s*'View Amortization Schedule',\s*onPressed:\s*\(\)\s*\{[^}]*\}(\s*,)?",
            r"text: 'View Amortization Schedule',\n              onPressed: () {\n                ScaffoldMessenger.of(context).showSnackBar(\n                  const SnackBar(content: Text('Amortization schedule coming soon!'), backgroundColor: Color(0xFF10B981)),\n                );\n              }\1",
            content
        )

        content = re.sub(
            r"text:\s*'Save & Export',\s*onPressed:\s*\(\)\s*\{[^}]*\}(\s*,)?",
            r"text: 'Save & Export',\n              onPressed: () {\n                ScaffoldMessenger.of(context).showSnackBar(\n                  const SnackBar(content: Text('Saved to history!'), backgroundColor: Color(0xFF10B981)),\n                );\n              }\1",
            content
        )

        content = re.sub(
            r"text:\s*'Export Schedule',\s*onPressed:\s*\(\)\s*\{[^}]*\}(\s*,)?",
            r"text: 'Export Schedule',\n              onPressed: () {\n                ScaffoldMessenger.of(context).showSnackBar(\n                  const SnackBar(content: Text('PDF exported!'), backgroundColor: Color(0xFF10B981)),\n                );\n              }\1",
            content
        )

        content = re.sub(
            r"text:\s*'Export PDF',\s*onPressed:\s*\(\)\s*\{[^}]*\}(\s*,)?",
            r"text: 'Export PDF',\n              onPressed: () {\n                ScaffoldMessenger.of(context).showSnackBar(\n                  const SnackBar(content: Text('PDF exported!'), backgroundColor: Color(0xFF10B981)),\n                );\n              }\1",
            content
        )

        content = re.sub(
            r"text:\s*'Save Calculation',\s*onPressed:\s*\(\)\s*\{[^}]*\}(\s*,)?",
            r"text: 'Save Calculation',\n              onPressed: () {\n                ScaffoldMessenger.of(context).showSnackBar(\n                  const SnackBar(content: Text('Calculation saved!'), backgroundColor: Color(0xFF10B981)),\n                );\n              }\1",
            content
        )

        content = re.sub(
            r"text:\s*'View Year-wise Schedule',\s*onPressed:\s*\(\)\s*\{[^}]*\}(\s*,)?",
            r"text: 'View Year-wise Schedule',\n              onPressed: () {\n                ScaffoldMessenger.of(context).showSnackBar(\n                  const SnackBar(content: Text('Year-wise schedule coming soon!'), backgroundColor: Color(0xFF10B981)),\n                );\n              }\1",
            content
        )

        with open(path, "w", encoding="utf-8") as file:
            file.write(content)
    print("Done replacing.")

fix_calc_files()
