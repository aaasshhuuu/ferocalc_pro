import re
with open(r"c:\projects\fincalc_pro\lib\features\compare\presentation\screens\compare_screen.dart", 'r', encoding='utf-8') as f:
    content = f.read()

# Let's fix the ending.
bad_end = """                          );
          } catch (e) {
            return const Center(child: Text('Something went wrong. Pull to refresh.'));
          }
        },
      ),
    );
  },
                  );
                }
              ),
            ),
          ],
        ))),
      );
    }"""

good_end = """                          );
                    },
                  );
                }
              ),
            ),
          ],
        ))),
            );
          } catch (e) {
            return const Center(child: Text('Something went wrong. Pull to refresh.'));
          }
        },
      ),
      );
    }"""

content = content.replace(bad_end, good_end)

with open(r"c:\projects\fincalc_pro\lib\features\compare\presentation\screens\compare_screen.dart", 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed compare_screen.dart")
