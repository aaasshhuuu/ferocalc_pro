import os
import re

# Directory to search
directory = r"c:\projects\fincalc_pro\lib"

# Regexes to replace
# Remove .scale(...), .slideY(...), .slideX(...)
# Remove delay: X.ms if X > 300
# Change duration > 300ms to duration: 300.ms
# Or simply strip all .animate() chains to just .animate().fade()
# Actually, the user said "Keep ONLY simple .fadeIn() or .fade() with short durations."

def simplify_animations(content):
    # This regex looks for .animate(...) and subsequent chains like .fade(...).slideY(...)
    # and simplifies them.
    # Actually, a safer approach is to replace common heavy animations:
    content = re.sub(r'\.slideY\([^)]*\)', '', content)
    content = re.sub(r'\.slideX\([^)]*\)', '', content)
    content = re.sub(r'\.scale\([^)]*\)', '', content)
    content = re.sub(r'\.shimmer\([^)]*\)', '', content)
    
    # Remove delay > 300ms. We can just remove delay arguments for simplicity, or find delay: \d+00\.ms
    content = re.sub(r'delay:\s*[4-9]\d{2}\.ms,?\s*', '', content)
    content = re.sub(r'delay:\s*\d{4,}\.ms,?\s*', '', content)
    
    # Replace interval > 300ms
    content = re.sub(r'interval:\s*[4-9]\d{2}\.ms,?\s*', '', content)
    content = re.sub(r'duration:\s*[4-9]\d{2}\.ms,?\s*', 'duration: 300.ms, ', content)
    
    # Clean up empty parens
    content = re.sub(r'\.fade\(\s*\)', '.fade()', content)
    content = re.sub(r'\.animate\(\s*\)', '.animate()', content)
    
    return content

for root, dirs, files in os.walk(directory):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                original_content = f.read()
            
            new_content = simplify_animations(original_content)
            
            if new_content != original_content:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print(f"Modified {filepath}")
