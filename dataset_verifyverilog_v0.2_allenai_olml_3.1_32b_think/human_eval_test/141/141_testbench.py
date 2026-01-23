import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

# Helper to convert string to 128-bit hex value (little-endian bytes)
def str_to_hex(s):
    if len(s) > 16:
        raise ValueError("String too long")
    hex_val = 0
    for i, char in enumerate(s):
        hex_val |= ord(char) << (i * 8)  # Little-endian: first char at LSB
    return hex_val

@cocotb.test()
async def test_file_name_check(dut):
    """Test the file_name_check module with various filenames"""
    
    # Test cases: (filename, expected_result)
    test_cases = [
        ("example.txt", True),
        ("1example.dll", False),  # starts with digit
        ("s1sdf3.asd", False),    # invalid extension
        ("K.dll", True),
        ("MY16FILE3.exe", True),
        ("His12FILE94.exe", False),  # too many digits (5)
        ("_Y.txt", False),        # starts with underscore
        ("?aREYA.exe", False),    # invalid start char
        ("/this_is_valid.dll", False), # invalid start char
        ("this_is_valid.wow", False),  # invalid extension
        ("this_is_valid.txt", True),
        ("this_is_valid.txtexe", False), # invalid extension
        ("#this2_i4s_5valid.ten", False), # invalid extension
        ("@this1_is6_valid.exe", False),  # invalid start char
        ("this_is_12valid.6exe4.txt", False), # multiple dots
        ("all.exe.txt", False),   # multiple dots
        ("I563_No.exe", True),
        ("Is3youfault.txt", True),
        ("no_one#knows.dll", True),
        ("1I563_Yes3.exe", False), # starts with digit
        ("I563_Yes3.txtt", False), # invalid extension
        ("final..txt", False),    # multiple dots
        ("final132", False),      # no dot
        ("_f4indsartal132.", False), # no suffix
        (".txt", False),          # empty prefix
        ("s.", False),            # empty suffix
    ]
    
    passed = 0
    total = len(test_cases)
    
    for filename, expected in test_cases:
        # Convert string to hex input
        hex_val = str_to_hex(filename)
        
        # Drive inputs
        dut.file_name.value = hex_val
        
        # Wait for combinational logic
        await Timer(10, units='ns')
        
        # Check result
        result = dut.is_valid.value
        expected_val = 1 if expected else 0
        
        if result == expected_val:
            passed += 1
            print(f"PASS: '{filename}' -> {'Yes' if expected else 'No'}")
        else:
            print(f"FAIL: '{filename}' -> Expected {'Yes' if expected else 'No'}, got {'Yes' if result else 'No'}")
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
