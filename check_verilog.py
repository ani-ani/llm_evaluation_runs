import os
import json
import re
import shutil
def starts_with_module(filepath):
    """Check if the file starts with the 'module' keyword (ignoring whitespace and comments)."""
    try:
        with open(filepath, 'r') as f:
            for line in f:
                stripped = line.strip()
                # Skip empty lines and comments
                if not stripped or stripped.startswith('//'):
                    continue
                return stripped.startswith('module')
        return False  # File is empty or only comments/whitespace
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
        return False

def is_systemverilog_file(filepath):
    """Check for basic SystemVerilog constructs."""
    sv_keywords = ['module', 'interface', 'package', 'endmodule']
    try:
        with open(filepath, 'r') as f:
            content = f.read()
            return any(kw in content for kw in sv_keywords)
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
        return False

def find_gen_sv_files(root_dir):
    """Yield all *_gen_*.sv files under root_dir recursively."""
    for dirpath, _, files in os.walk(root_dir):
        for fname in files:
            if '_gen_' in fname and fname.endswith('.sv'):
                yield os.path.join(dirpath, fname)


def extract_json_from_sv_file(filepath):
    with open(filepath, 'r', encoding = 'utf-8') as f:
        content = f.read()
    # Remove comment lines and markdown code block markers
    # Find the first '{' and the last '}'
    match = re.search(r'({.*})', content, re.DOTALL)
    if not match:
        raise ValueError("No JSON object found in file")
    json_str = match.group(1)
    return json.loads(json_str)
    
def process_failed_sv_file(sv_file):
    base_dir = os.path.dirname(sv_file)
    base_name = os.path.basename(sv_file)
    name_no_ext = os.path.splitext(base_name)[0]
    org_file = os.path.join(base_dir, f"{name_no_ext}_org_failed.sv")
    sv_code_file = os.path.join(base_dir, f"{name_no_ext}.sv")
    # Step 1: Move the original file to _org_failed.sv
    #shutil.move(sv_file, org_file)
    # Step 2: Read and process the moved file
    try:
        data = extract_json_from_sv_file(sv_file)
        sv_code = data.get("code", "")
    except Exception as e:
        print(f"Error extracting JSON from {sv_file}: {e}")
        return
    # Step 3: Write the extracted SV code to the original file name
    with open(sv_code_file, 'w') as f:
        f.write(sv_code)
    print(f"Original file moved to: {sv_file}")
    #print(f"Extracted SV code written to: {sv_code_file}")

def main(root_dir):
    for sv_file in find_gen_sv_files(root_dir):
        if not is_systemverilog_file(sv_file) or not starts_with_module(sv_file):
            print(f"File failed checks: {sv_file}")
            process_failed_sv_file(sv_file)

if __name__ == "__main__":
    main(r'C:\Users\durgamaniryudh\Desktop\Learn\llm_eval\dataset_verifyverilog_deepseek')  # Change this to your directory