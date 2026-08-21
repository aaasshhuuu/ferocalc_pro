import os
import re

files_to_update = [
    r"c:\projects\fincalc_pro\lib\features\home\presentation\screens\home_screen.dart",
    r"c:\projects\fincalc_pro\lib\features\calculators_hub\presentation\screens\calculators_hub_screen.dart",
    r"c:\projects\fincalc_pro\lib\features\compare\presentation\screens\compare_screen.dart",
    r"c:\projects\fincalc_pro\lib\features\profile\presentation\screens\profile_screen.dart",
]

def add_error_boundary(file_path):
    if not os.path.exists(file_path):
        print(f"File not found: {file_path}")
        # Try to find the file if path is slightly different
        base_name = os.path.basename(file_path)
        for root, dirs, files in os.walk(r"c:\projects\fincalc_pro\lib"):
            if base_name in files:
                file_path = os.path.join(root, base_name)
                break
        else:
            return

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Avoid double wrapping
    if "try {" in content and "Something went wrong" in content:
        print(f"Already wrapped: {file_path}")
        return

    # Check if we have body: SafeArea( or body: something
    # We want to replace body: <Widget>( with
    # body: SafeArea(child: Builder(builder: (context) { try { return <Widget>(
    
    # Let's find the `Widget build(BuildContext context) { ... return Scaffold( ... body: `
    
    body_match = re.search(r'body:\s*([A-Za-z0-9_]+)\(', content)
    if not body_match:
        print(f"Could not find body in {file_path}")
        return
        
    widget_name = body_match.group(1)
    
    if widget_name == "SafeArea":
        # It's already a SafeArea, let's wrap its child.
        # body: SafeArea(
        #   child: LayoutBuilder(
        safearea_idx = content.find("body: SafeArea(")
        if safearea_idx == -1:
            safearea_idx = content.find("body: const SafeArea(")
            
        child_match = re.search(r'child:\s*([A-Za-z0-9_]+)\(', content[safearea_idx:])
        if child_match:
            old_child_decl = child_match.group(0) # e.g. child: LayoutBuilder(
            new_child_decl = f"""child: Builder(
        builder: (context) {{
          try {{
            return {old_child_decl[7:]}"""
            
            content = content[:safearea_idx] + content[safearea_idx:].replace(old_child_decl, new_child_decl, 1)
            
            # Close the try catch at the end of build method
            # This is tricky without a proper parser. We can just replace the end of the build method.
            end_pattern = r"(\s*)\)\s*,\s*\n\s*\)\s*;\s*\n\s*}"
            match = re.search(end_pattern, content)
            if match:
                content = content[:match.start()] + match.group(1) + """);
          } catch (e) {
            return const Center(child: Text('Something went wrong. Pull to refresh.'));
          }
        },
      ),
    );
  }""" + content[match.end():]
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"Updated {file_path}")
            else:
                # alternative end pattern
                end_pattern2 = r"(\s*)\)\s*;\s*\n\s*}"
                match2 = re.search(end_pattern2, content)
                if match2:
                    content = content[:match2.start()] + match2.group(1) + """);
          } catch (e) {
            return const Center(child: Text('Something went wrong. Pull to refresh.'));
          }
        },
      ),
    );
  }""" + content[match2.end():]
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(content)
                    print(f"Updated {file_path} (alt pattern)")
                else:
                    print(f"Could not find end of build in {file_path}")
    else:
        # Wrap with SafeArea and Builder
        old_body_decl = body_match.group(0) # body: Center(
        new_body_decl = f"""body: SafeArea(
      child: Builder(
        builder: (context) {{
          try {{
            return {widget_name}("""
        
        content = content.replace(old_body_decl, new_body_decl, 1)
        
        end_pattern = r"(\s*)\)\s*,\s*\n\s*\)\s*;\s*\n\s*}"
        match = re.search(end_pattern, content)
        if match:
            content = content[:match.start()] + match.group(1) + """);
          } catch (e) {
            return const Center(child: Text('Something went wrong. Pull to refresh.'));
          }
        },
      ),
    );
  }""" + content[match.end():]
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Updated {file_path} (wrapped with SafeArea)")
        else:
             # alternative end pattern
            end_pattern2 = r"(\s*)\)\s*;\s*\n\s*}"
            match2 = re.search(end_pattern2, content)
            if match2:
                content = content[:match2.start()] + match2.group(1) + """);
          } catch (e) {
            return const Center(child: Text('Something went wrong. Pull to refresh.'));
          }
        },
      ),
    );
  }""" + content[match2.end():]
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"Updated {file_path} (wrapped with SafeArea, alt pattern)")
            else:
                print(f"Could not find end of build in {file_path}")

for f in files_to_update:
    add_error_boundary(f)
