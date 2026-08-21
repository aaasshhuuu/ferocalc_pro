import re
with open(r"c:\projects\fincalc_pro\lib\features\home\presentation\screens\home_screen.dart", 'r', encoding='utf-8') as f:
    content = f.read()

# I need to clean up the duplicated ends.
# I will just find body: SafeArea( ... and rebuild it.
import shutil
shutil.copy(r"c:\projects\fincalc_pro\lib\features\home\presentation\screens\home_screen.dart", r"c:\projects\fincalc_pro\lib\features\home\presentation\screens\home_screen.dart.bak")

# Actually, I know exactly what I injected.
old_injection = """      body: SafeArea(
        child: Builder(
        builder: (context) {
          try {
            return LayoutBuilder("""

new_injection = """      body: SafeArea(
        child: LayoutBuilder("""

content = content.replace(old_injection, new_injection)

# Now fix the end.
end_injection = """              );
          } catch (e) {
            return const Center(child: Text('Something went wrong. Pull to refresh.'));
          }
        },
      ),
    );
  }
        ),
      ),
    );
  }"""

new_end = """              ),
            );
          }
        ),
      ),
    );
  }"""

content = content.replace(end_injection, new_end)

# Let's see if that correctly restores it. Then apply properly.

# But actually let's re-run python script that just does:
content = content.replace("child: LayoutBuilder(", """child: Builder(
          builder: (context) {
            try {
              return LayoutBuilder(""")

end_target = """            );
          }
        ),
      ),
    );
  }"""

new_end_target = """            );
            } catch(e) { return const Center(child: Text('Something went wrong. Pull to refresh.')); }
          }
        ),
      ),
    );
  }"""

content = content.replace(end_target, new_end_target)

with open(r"c:\projects\fincalc_pro\lib\features\home\presentation\screens\home_screen.dart", 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed home_screen.dart")
