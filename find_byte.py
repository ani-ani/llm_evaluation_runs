import re
import json

file_path = r"C:\Users\durgamaniryudh\Desktop\Learn\llm_eval\dataset_verifyverilog_minmax\aapp_competition_test\3425\3425_gen_0.sv"


def print_code_value(filepath):
    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    # Regex to extract the value of the "code" key (handles multiline and escaped quotes)
    match = re.search(r'"code"\s*:\s*"((?:[^"\\]|\\.)*)"', content, re.DOTALL)
    if match:
        # Unescape common escape sequences
        code_str = match.group(1)
        code_str = code_str.encode('utf-8').decode('unicode_escape')
        print(code_str)
    else:
        print("Could not find a 'code' key in the file.")

# Usage:
print_code_value(file_path)

