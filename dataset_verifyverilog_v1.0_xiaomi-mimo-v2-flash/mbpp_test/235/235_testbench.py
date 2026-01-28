import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_even_bit_set(dut):
    # Test even_bit_set_number function with fixed 16-bit width
    # Expected: n | 0x5555 (sets even bits 0,2,4,6,8,10,12,14)
    
    test_cases = [
        (10, 26, "Test 1: 10 -> 26 (0x000A | 0x5555 = 0x001A = 26)"),
        (20, 30, "Test 2: 20 -> 30 (0x0014 | 0x5555 = 0x001E = 30)"),
        (30, 30, "Test 3: 30 -> 30 (0x001E | 0x5555 = 0x001E = 30)"),
        (0, 21845, "Edge: 0 -> 21845 (0x0000 | 0x5555 = 0x5555)"),
        (65535, 65535, "Edge: 0xFFFF -> 65535 (all bits set)"),
        (1, 1, "Edge: 1 -> 1 (bit 0 already set, odd bits preserved)"),
        (2, 3, "Edge: 2 -> 3 (0x0002 | 0x5555 = 0x0003 = 3)"),
    ]
    
    passed = failed = 0
    
    for i, (n_input, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Assign input
            if has_signal(dut, 'n'):
                dut.n.value = clamp_to_width(n_input, 16)
            else:
                raise TestFailure("Missing input signal 'n'")
            
            # Wait for combinational logic
            await Timer(100, units='ns')
            
            # Read result
            if not has_signal(dut, 'result'):
                raise TestFailure("Missing output signal 'result'")
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            
            # Expected calculation with 16-bit mask
            expected_result = n_input | 0x5555
            expected_result = clamp_to_width(expected_result, 16)
            
            if result != expected_result:
                raise TestFailure(f"Expected {expected_result}, got {result}")
            
            if result != expected:
                raise TestFailure(f"Test case mismatch: Expected {expected}, got {result}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")