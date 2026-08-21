import re
with open(r"c:\projects\fincalc_pro\lib\features\calculators\presentation\screens\calculators_hub_screen.dart", 'r', encoding='utf-8') as f:
    content = f.read()

bad_catch = """      const SnackBar(content: Text('Share feature coming soon!'), backgroundColor: Color(0xFF10B981));
          } catch (e) {
            return const Center(child: Text('Something went wrong. Pull to refresh.'));
          }
        },
      ),
    );
  }"""

good_snack = """      const SnackBar(content: Text('Share feature coming soon!'), backgroundColor: Color(0xFF10B981)),
    );
  }"""

content = content.replace(bad_catch, good_snack)

bad_end = """        ],
      ))),
    );
  }
}"""

good_end = """        ],
      ))),
            );
          } catch (e) {
            return const Center(child: Text('Something went wrong. Pull to refresh.'));
          }
        },
      ),
      );
    }
}"""

content = content.replace(bad_end, good_end)

with open(r"c:\projects\fincalc_pro\lib\features\calculators\presentation\screens\calculators_hub_screen.dart", 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed calculators_hub_screen.dart")
