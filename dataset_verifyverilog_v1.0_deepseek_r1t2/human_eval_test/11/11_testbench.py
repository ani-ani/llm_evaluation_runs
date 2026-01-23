import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import random

# Helper function to check if value is defined
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def to_binary_string(value, width=16):
    """Convert integer to binary string representation."""
    return format(value, f'0{width}b')

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_string_xor_basic(dut):
    """Test basic XOR operations on fixed-width binary strings."""
    
    dut._log.info("Testing string_xor module")
    
    # Test cases adapted for 16-bit width
    test_cases = [
        # (a_dec, b_dec, expected_dec, description)
        (0b111000, 0b101010, 0b010010, "6-bit patterns, padded to 16 bits"),
        (0b1, 0b1, 0b0, "Single 1 bits"),
        (0b0101, 0b0000, 0b0101, "One input all zeros"),
        (0xFFFF, 0xFFFF, 0x0000, "All ones XOR all ones"),
        (0x0000, 0x0000, 0x0000, "All zeros XOR all zeros"),
        (0xAAAA, 0x5555, 0xFFFF, "Alternating patterns"),
        (0x1234, 0xABCD, 0xB9F9, "Random 16-bit values"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (a_val, b_val, expected, desc) in enumerate(test_cases):
        # Set inputs
        dut.a.value = a_val
        dut.b.value = b_val
        
        # Wait for combinational logic to propagate
        await Timer(10, units='ns')
        
        # Check output is defined
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i}: Output is undefined (X/Z)")
        
        # Read result
        result = int(dut.result.value)
        
        # Verify
        if result != expected:
            a_bin = to_binary_string(a_val)
            b_bin = to_binary_string(b_val)
            exp_bin = to_binary_string(expected)
            res_bin = to_binary_string(result)
            raise TestFailure(
                f"Test {i} failed: {desc}\n"
                f"  a      = {a_bin}\n"
                f"  b      = {b_bin}\n"
                f"  expect = {exp_bin}\n"
                f"  got    = {res_bin}"
            )
        
        passed += 1
        dut._log.info(f"Test {i} passed: {desc}")
    
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_string_xor_random(dut):
    """Test with random 16-bit values."""
    
    random.seed(42)
    num_tests = 20
    passed = 0
    
    dut._log.info(f"Running {num_tests} random tests")
    
    for i in range(num_tests):
        a_val = random.randint(0, 0xFFFF)
        b_val = random.randint(0, 0xFFFF)
        expected = a_val ^ b_val
        
        dut.a.value = a_val
        dut.b.value = b_val
        
        await Timer(10, units='ns')
        
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Random test {i}: Output is undefined")
        
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(
                f"Random test {i} failed: {a_val} ^ {b_val} != {expected}, got {result}"
            )
        
        passed += 1
    
    dut._log.info(f"\nRandom test summary: {passed}/{num_tests} passed")

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_string_xor_edge_cases(dut):
    """Test edge cases and boundary values."""
    
    dut._log.info("Testing edge cases")
    
    # Edge case: only MSB set
    dut.a.value = 0x8000
    dut.b.value = 0x0000
    await Timer(10, units='ns')
    result = int(dut.result.value)
    if result != 0x8000:
        raise TestFailure(f"MSB test failed: expected 0x8000, got {hex(result)}")
    
    # Edge case: only LSB set
    dut.a.value = 0x0001
    dut.b.value = 0x0000
    await Timer(10, units='ns')
    result = int(dut.result.value)
    if result != 0x0001:
        raise TestFailure(f"LSB test failed: expected 0x0001, got {hex(result)}")
    
    # Edge case: alternating in LSB
    dut.a.value = 0x0055  # 01010101
    dut.b.value = 0x00AA  # 10101010
    await Timer(10, units='ns')
    result = int(dut.result.value)
    if result != 0x00FF:
        raise TestFailure(f"Alternating LSB failed: expected 0x00FF, got {hex(result)}")
    
    dut._log.info("Edge case tests passed")
