import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import random

# Helper function to check if value is defined (not X/Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# ASCII classification helpers
def is_upper(c):
    return 65 <= c <= 90

def is_lower(c):
    return 97 <= c <= 122

def calculate_strength(s):
    """Calculate strength for a string: uppercase - lowercase"""
    s_bytes = s.encode('ascii')
    strength = 0
    for b in s_bytes:
        if is_upper(b):
            strength += 1
        elif is_lower(b):
            strength -= 1
    return strength

# Helper to assign string to dut array
def assign_string(dut, array_name, string_val, max_len):
    """Assign a string to a Verilog array (max_len elements, each 8 bits)"""
    # Pad with zeros (null) if string shorter than max_len
    bytes_val = string_val.encode('ascii')
    for i in range(max_len):
        if i < len(bytes_val):
            getattr(dut, array_name)[i].value = bytes_val[i]
        else:
            getattr(dut, array_name)[i].value = 0

# Helper to read result string from dut
def read_result_string(dut, max_len=25):
    """Read result string from dut output array"""
    result_bytes = []
    for i in range(max_len):
        val = getattr(dut, f'result[{i}]').value
        if is_value_defined(val):
            b = int(val)
            if b != 0:  # Stop at null terminator
                result_bytes.append(b)
            else:
                break
        else:
            # Stop if undefined
            break
    return bytes(result_bytes).decode('ascii')

@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_strongest_extension(dut):
    """Test strongest_extension module with multiple test cases"""
    
    # Test cases: (class_name, extensions_list, expected_result)
    test_cases = [
        ('Watashi', ['tEN', 'niNE', 'eIGHt8OKe'], 'Watashi.eIGHt8OKe'),
        ('Boku123', ['nani', 'NazeDa', 'YEs.WeCaNe', '32145tggg'], 'Boku123.YEs.WeCaNe'),
        ('__YESIMHERE', ['t', 'eMptY', 'nothing', 'zeR00', 'NuLl__', '123NoooneB321'], '__YESIMHERE.NuLl__'),
        ('K', ['Ta', 'TAR', 't234An', 'cosSo'], 'K.TAR'),
        ('__HAHA', ['Tab', '123', '781345', '-_-'], '__HAHA.123'),
        ('YameRore', ['HhAas', 'okIWILL123', 'WorkOut', 'Fails', '-_-'], 'YameRore.okIWILL123'),
        ('finNNalLLly', ['Die', 'NowW', 'Wow', 'WoW'], 'finNNalLLly.WoW'),
        ('_', ['Bb', '91245'], '_.Bb'),
        ('Sp', ['671235', 'Bb'], 'Sp.671235'),
        # Additional edge cases
        ('A', ['Zz'], 'A.Zz'),  # Negative strength
        ('Test', ['AAA', 'aaa', 'Abc'], 'Test.AAA'),  # Positive strength with tie
    ]
    
    # Set clock to 0 (not used but good practice)
    dut._log.info(f"Starting tests with {len(test_cases)} test cases")
    
    for i, (class_name, extensions, expected) in enumerate(test_cases):
        dut._log.info(f"Test case {i+1}: {class_name} with {len(extensions)} extensions")
        
        # Calculate expected strength for debugging
        best_strength = float('-inf')
        best_idx = 0
        for idx, ext in enumerate(extensions):
            strength = calculate_strength(ext)
            if strength > best_strength:
                best_strength = strength
                best_idx = idx
        dut._log.info(f"  Expected: {expected} (strength={best_strength}, idx={best_idx})")
        
        # Clear all inputs first
        # Assign class name
        class_bytes = class_name.encode('ascii')
        for j in range(8):
            if j < len(class_bytes):
                dut.class_name[j].value = class_bytes[j]
            else:
                dut.class_name[j].value = 0
        
        # Assign extensions
        for ext_idx in range(8):
            if ext_idx < len(extensions):
                ext_str = extensions[ext_idx]
                ext_bytes = ext_str.encode('ascii')
                for char_idx in range(16):
                    if char_idx < len(ext_bytes):
                        dut.extensions[ext_idx][char_idx].value = ext_bytes[char_idx]
                    else:
                        dut.extensions[ext_idx][char_idx].value = 0
                # Assign extension length
                dut.ext_lens[ext_idx].value = len(ext_str)
            else:
                # Clear unused extensions
                for char_idx in range(16):
                    dut.extensions[ext_idx][char_idx].value = 0
                dut.ext_lens[ext_idx].value = 0
        
        # Assign count and class length
        dut.ext_count.value = len(extensions)
        dut.class_len.value = len(class_name)
        
        # Wait for combinational logic to propagate
        await Timer(50, units='ns')
        
        # Check result validity
        if not is_value_defined(dut.result_len.value):
            raise TestFailure(f"Test {i+1}: result_len is undefined")
        
        result_len = int(dut.result_len.value)
        
        # Read result string
        result_str = read_result_string(dut, max_len=25)
        
        # Verify
        if result_str != expected:
            raise TestFailure(f"Test {i+1}: Expected '{expected}', got '{result_str}' (len={result_len})")
        
        dut._log.info(f"  Result: '{result_str}' [PASS]")
    
    dut._log.info(f"\nAll {len(test_cases)} tests passed!")
