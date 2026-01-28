import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
STRING_WIDTH = 32  # 4 characters x 8 bits
BOOL_WIDTH = 1
RESULT_WIDTH = 8

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def pack_string(s):
    """Pack up to 4 characters into 32-bit value."""
    result = 0
    for i, c in enumerate(s[:4]):
        result |= (ord(c) << (i * 8))
    return result

def unpack_string(val):
    """Unpack 32-bit value to 4-character string."""
    chars = []
    for i in range(4):
        char_val = (val >> (i * 8)) & 0xFF
        if char_val != 0:
            chars.append(chr(char_val))
    return ''.join(chars)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_colon_tuplex(dut):
    """Test tuple modification with list append."""
    
    # Test cases: (tuple_str, tuple_num, tuple_list, tuple_bool, m, n, expected_list, description)
    test_cases = [
        ("HELLO", 5, 0, True, 2, 50, 50, "Append 50 to list"),
        ("HELLO", 5, 0, True, 2, 100, 100, "Append 100 to list"),
        ("HELLO", 5, 0, True, 2, 500, 244, "Append 500 (clamped to 8-bit)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (t_str, t_num, t_list, t_bool, m, n, expected_list, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Pack string input
            str_packed = pack_string(t_str)
            
            # Assign inputs
            dut.tuple_str.value = str_packed
            dut.tuple_num.value = t_num
            dut.tuple_list.value = t_list
            dut.tuple_bool.value = 1 if t_bool else 0
            dut.append_val.value = n
            dut.m.value = m
            dut.n.value = n
            
            # Wait for combinational propagation
            await Timer(10, units='ns')
            
            # Check outputs
            if not all([is_value_defined(dut.result_str.value),
                       is_value_defined(dut.result_num.value),
                       is_value_defined(dut.result_list.value),
                       is_value_defined(dut.result_bool.value)]):
                raise TestFailure("Output contains undefined values (X/Z)")
            
            # Verify string unchanged
            result_str = int(dut.result_str.value)
            if result_str != str_packed:
                raise TestFailure(f"String changed: expected {str_packed}, got {result_str}")
            
            # Verify number unchanged
            result_num = int(dut.result_num.value)
            if result_num != t_num:
                raise TestFailure(f"Number changed: expected {t_num}, got {result_num}")
            
            # Verify list element updated
            result_list = int(dut.result_list.value)
            if result_list != expected_list:
                raise TestFailure(f"List mismatch: expected {expected_list}, got {result_list}")
            
            # Verify boolean unchanged
            result_bool = int(dut.result_bool.value)
            expected_bool = 1 if t_bool else 0
            if result_bool != expected_bool:
                raise TestFailure(f"Boolean changed: expected {expected_bool}, got {result_bool}")
            
            cocotb.log.info(f"  PASS: String='{t_str}', Num={t_num}, List={result_list}, Bool={t_bool}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")