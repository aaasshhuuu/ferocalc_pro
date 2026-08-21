import os
import re

file_path = r"c:\projects\fincalc_pro\lib\features\insights\presentation\screens\insights_screen.dart"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Change timer
content = content.replace("Timer.periodic(const Duration(seconds: 10), (_) => _fetchMarketData());", "Timer.periodic(const Duration(seconds: 30), (_) => _fetchMarketData());")

# 2. Add fallbackMarket
fallback_code = """
  final Map<String, dynamic> fallbackMarket = {
    'sensex': {'value': 82365.77, 'change': 0.45},
    'nifty50': {'value': 25145.10, 'change': 0.38},
    'bankNifty': {'value': 51234.60, 'change': -0.12},
    'gold10g': {'value': 73850, 'change': 0.65},
    'silver1kg': {'value': 89200, 'change': 0.42},
    'usdInr': {'value': 83.42, 'change': -0.08},
    'crudeOil': {'value': 78.50, 'change': 1.20},
    'rbiRepoRate': 6.50,
  };
"""

content = content.replace("bool _isLoading = false;", fallback_code + "\n  bool _isLoading = false;")

# 3. Add SafeArea and Builder for error boundary
# Replace body: Center( -> body: SafeArea(child: Builder(builder: (context) { try { return Center(
# And close it properly.

body_start_idx = content.find("body: Center(")
if body_start_idx != -1:
    old_body = "body: Center("
    new_body = """body: SafeArea(
      child: Builder(
        builder: (context) {
          try {
            return Center("""
    content = content.replace(old_body, new_body, 1)
    
    # Now we need to close it. The build method ends with:
    #       ))),
    #     );
    #   }
    
    end_pattern = r"(\s*)\)\)\),\s*\n\s*\);\s*\n\s*}"
    match = re.search(end_pattern, content)
    if match:
        old_end = match.group(0)
        new_end = """
            )));
          } catch (e) {
            return Center(child: Text('Something went wrong. Pull to refresh.', style: TextStyle(color: textColor)));
          }
        },
      ),
    );
  }"""
        content = content.replace(old_end, new_end, 1)

# 4. Use fallback market data if _marketData is null or keys are missing.
# We will replace _marketData?.data['sensex']?['value']?.toString() ?? '82,365.77'
# with _marketData?.data['sensex']?['value']?.toString() ?? fallbackMarket['sensex']['value'].toString()

replacements = [
    (r"_marketData\?\.data\['sensex'\]\?\['value'\]\?\.toString\(\) \?\? '82,365\.77'", r"(_marketData?.data['sensex']?['value'] ?? fallbackMarket['sensex']['value']).toString()"),
    (r"\(_marketData\?\.data\['sensex'\]\?\['change'\] \?\? 0\.45\) >= 0", r"(_marketData?.data['sensex']?['change'] ?? fallbackMarket['sensex']['change']) >= 0"),
    (r"'\$\{\_marketData\?\.data\['sensex'\]\?\['change'\] \?\? '\+0\.45'\}%'", r"'${(_marketData?.data['sensex']?['change'] ?? fallbackMarket['sensex']['change']) >= 0 ? '+' : ''}${_marketData?.data['sensex']?['change'] ?? fallbackMarket['sensex']['change']}%'"),

    (r"_marketData\?\.data\['nifty50'\]\?\['value'\]\?\.toString\(\) \?\? '25,145\.10'", r"(_marketData?.data['nifty50']?['value'] ?? fallbackMarket['nifty50']['value']).toString()"),
    (r"\(_marketData\?\.data\['nifty50'\]\?\['change'\] \?\? 0\.38\) >= 0", r"(_marketData?.data['nifty50']?['change'] ?? fallbackMarket['nifty50']['change']) >= 0"),
    (r"'\$\{\_marketData\?\.data\['nifty50'\]\?\['change'\] \?\? '\+0\.38'\}%'", r"'${(_marketData?.data['nifty50']?['change'] ?? fallbackMarket['nifty50']['change']) >= 0 ? '+' : ''}${_marketData?.data['nifty50']?['change'] ?? fallbackMarket['nifty50']['change']}%'"),

    (r"_marketData\?\.data\['bankNifty'\]\?\['value'\]\?\.toString\(\) \?\? '51,234\.60'", r"(_marketData?.data['bankNifty']?['value'] ?? fallbackMarket['bankNifty']['value']).toString()"),
    (r"\(_marketData\?\.data\['bankNifty'\]\?\['change'\] \?\? -0\.12\) >= 0", r"(_marketData?.data['bankNifty']?['change'] ?? fallbackMarket['bankNifty']['change']) >= 0"),
    (r"'\$\{\_marketData\?\.data\['bankNifty'\]\?\['change'\] \?\? '-0\.12'\}%'", r"'${(_marketData?.data['bankNifty']?['change'] ?? fallbackMarket['bankNifty']['change']) >= 0 ? '+' : ''}${_marketData?.data['bankNifty']?['change'] ?? fallbackMarket['bankNifty']['change']}%'"),

    (r"'₹\$\{\_marketData\?\.data\['gold10g'\]\?\['value'\] \?\? '73,850'\}'", r"'₹${_marketData?.data['gold10g']?['value'] ?? fallbackMarket['gold10g']['value']}'"),
    (r"\(_marketData\?\.data\['gold10g'\]\?\['change'\] \?\? 0\.65\) >= 0", r"(_marketData?.data['gold10g']?['change'] ?? fallbackMarket['gold10g']['change']) >= 0"),
    (r"'\$\{\_marketData\?\.data\['gold10g'\]\?\['change'\] \?\? '\+0\.65'\}%'", r"'${(_marketData?.data['gold10g']?['change'] ?? fallbackMarket['gold10g']['change']) >= 0 ? '+' : ''}${_marketData?.data['gold10g']?['change'] ?? fallbackMarket['gold10g']['change']}%'"),

    (r"'₹\$\{\_marketData\?\.data\['silver1kg'\]\?\['value'\] \?\? '89,200'\}'", r"'₹${_marketData?.data['silver1kg']?['value'] ?? fallbackMarket['silver1kg']['value']}'"),
    (r"\(_marketData\?\.data\['silver1kg'\]\?\['change'\] \?\? 0\.42\) >= 0", r"(_marketData?.data['silver1kg']?['change'] ?? fallbackMarket['silver1kg']['change']) >= 0"),
    (r"'\$\{\_marketData\?\.data\['silver1kg'\]\?\['change'\] \?\? '\+0\.42'\}%'", r"'${(_marketData?.data['silver1kg']?['change'] ?? fallbackMarket['silver1kg']['change']) >= 0 ? '+' : ''}${_marketData?.data['silver1kg']?['change'] ?? fallbackMarket['silver1kg']['change']}%'"),

    (r"'₹\$\{\_marketData\?\.data\['usdInr'\]\?\['value'\] \?\? '83\.42'\}'", r"'₹${_marketData?.data['usdInr']?['value'] ?? fallbackMarket['usdInr']['value']}'"),
    (r"\(_marketData\?\.data\['usdInr'\]\?\['change'\] \?\? -0\.08\) >= 0", r"(_marketData?.data['usdInr']?['change'] ?? fallbackMarket['usdInr']['change']) >= 0"),
    (r"'\$\{\_marketData\?\.data\['usdInr'\]\?\['change'\] \?\? '-0\.08'\}%'", r"'${(_marketData?.data['usdInr']?['change'] ?? fallbackMarket['usdInr']['change']) >= 0 ? '+' : ''}${_marketData?.data['usdInr']?['change'] ?? fallbackMarket['usdInr']['change']}%'"),

    (r"'\$\{\_marketData\?\.data\['crudeOil'\]\?\['value'\] \?\? '78\.50'\}'", r"(_marketData?.data['crudeOil']?['value'] ?? fallbackMarket['crudeOil']['value']).toString()"),
    (r"\(_marketData\?\.data\['crudeOil'\]\?\['change'\] \?\? 1\.20\) >= 0", r"(_marketData?.data['crudeOil']?['change'] ?? fallbackMarket['crudeOil']['change']) >= 0"),
    (r"'\$\{\_marketData\?\.data\['crudeOil'\]\?\['change'\] \?\? '\+1\.20'\}%'", r"'${(_marketData?.data['crudeOil']?['change'] ?? fallbackMarket['crudeOil']['change']) >= 0 ? '+' : ''}${_marketData?.data['crudeOil']?['change'] ?? fallbackMarket['crudeOil']['change']}%'"),

    (r"'\$\{\_marketData\?\.data\['rbiRepoRate'\] \?\? '6\.50'\}%'", r"'${_marketData?.data['rbiRepoRate'] ?? fallbackMarket['rbiRepoRate']}%'"),
]

for old, new in replacements:
    content = re.sub(old, new, content)

# One fix for crude oil display
content = content.replace(r"'$(_marketData?.data['crudeOil']?['value'] ?? fallbackMarket['crudeOil']['value']).toString()'", r"'\$${_marketData?.data['crudeOil']?['value'] ?? fallbackMarket['crudeOil']['value']}'")
content = content.replace(r"'\$(_marketData?.data['crudeOil']?['value'] ?? fallbackMarket['crudeOil']['value']).toString()'", r"'\$${_marketData?.data['crudeOil']?['value'] ?? fallbackMarket['crudeOil']['value']}'")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated insights_screen.dart")
