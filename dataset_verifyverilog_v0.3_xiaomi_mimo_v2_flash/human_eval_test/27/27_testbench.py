import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=1, timeout_unit="ms")
async def test_flip_case_basic(dut):
    """Test basic case flipping for 'Hello' -> 'hELLO' (padded with nulls)"""
    
    # Input: 'Hello\x00\x00\x00'
    input_str = 'Hello'
    input_chars = [ord(c) for c in input_str] + [0x00] * (8 - len(input_str))
    
    # Expected: 'hELLO\x00\x00\x00' (nulls remain nulls)
    expected_str = 'hELLO'
    expected_chars = [ord(c) for c in expected_str] + [0x00] * (8 - len(expected_str))
    
    # Set inputs
    for i, val in enumerate(input_chars):
        getattr(dut, f'char_{i}').value = val
    
    # Wait for combinational propagation
    await Timer(10, units='ns')
    
    # Check outputs
    for i in range(8):
        if not is_value_defined(getattr(dut, f'result_{i}').value):
            raise TestFailure(f"Output result_{i} is undefined (X/Z)")
        
        result = int(getattr(dut, f'result_{i}').value)
        if result != expected_chars[i]:
            raise TestFailure(f"Char {i}: expected {expected_chars[i]:02X} got {result:02X}")
    
    dut._log.info("Test 1 passed: 'Hello' -> 'hELLO'")

@cocotb.test(timeout_time=1, timeout_unit="ms")
async def test_flip_case_punctuation(dut):
    """Test 'Hello!' -> 'hELLO!' (punctuation remains unchanged)"""
    
    # Input: 'Hello!' + nulls
    input_str = 'Hello!'
    input_chars = [ord(c) for c in input_str] + [0x00] * (8 - len(input_str))
    
    # Expected: 'hELLO!' + nulls
    expected_str = 'hELLO!'
    expected_chars = [ord(c) for c in expected_str] + [0x00] * (8 - len(expected_str))
    
    for i, val in enumerate(input_chars):
        getattr(dut, f'char_{i}').value = val
    
    await Timer(10, units='ns')
    
    for i in range(8):
        if not is_value_defined(getattr(dut, f'result_{i}').value):
            raise TestFailure(f"Output result_{i} is undefined")
        
        result = int(getattr(dut, f'result_{i}').value)
        if result != expected_chars[i]:
            raise TestFailure(f"Char {i}: expected {chr(expected_chars[i])} ({expected_chars[i]:02X}) got {chr(result)} ({result:02X})")
    
    dut._log.info("Test 2 passed: 'Hello!' -> 'hELLO!'")

@cocotb.test(timeout_time=1, timeout_unit="ms")
async def test_flip_case_mixed_sentence(dut):
    """Test 'These v' -> 'tHESE V' (first 8 chars of long sentence)"""
    
    # Full string: 'These violent delights have violent ends'
    # We adapt to 8-char limit: 'These v'
    # T(84)->t(116), h(104)->H(72), e(101)->E(69), s(115)->S(83), e(101)->E(69), [space](32)->[space](32), v(118)->V(86), i(105)->I(73)
    
    input_str = 'These v'
    input_chars = [ord(c) for c in input_str]
    expected_str = 'tHESE V'
    expected_chars = [ord(c) for c in expected_str]
    
    # We will also test the full 8-length, padding if needed, but here it matches exactly
    # Let's fill to 8 just to be safe
    input_chars = input_chars + [0x00] * (8 - len(input_chars))
    expected_chars = expected_chars + [0x00] * (8 - len(expected_chars))
    
    for i, val in enumerate(input_chars):
        getattr(dut, f'char_{i}').value = val
    
    await Timer(10, units='ns')
    
    for i in range(8):
        if not is_value_defined(getattr(dut, f'result_{i}').value):
            raise TestFailure(f"Output result_{i} is undefined")
        
        result = int(getattr(dut, f'result_{i}').value)
        if result != expected_chars[i]:
            raise TestFailure(f"Char {i}: expected {expected_chars[i]:02X} got {result:02X}")
    
    dut._log.info("Test 3 passed: 'These v' -> 'tHESE V'")

@cocotb.test(timeout_time=1, timeout_unit="ms")
async def test_flip_case_mixed_boundaries(dut):
    """Test 'AbCdEfGh' -> 'aBcDeFgH' (alternating case)"""
    
    input_str = 'AbCdEfGh'
    expected_str = 'aBcDeFgH'
    
    input_chars = [ord(c) for c in input_str]
    expected_chars = [ord(c) for c in expected_str]
    
    for i, val in enumerate(input_chars):
        getattr(dut, f'char_{i}').value = val
    
    await Timer(10, units='ns')
    
    for i in range(8):
        if not is_value_defined(getattr(dut, f'result_{i}').value):
            raise TestFailure(f"Output result_{i} is undefined")
        
        result = int(getattr(dut, f'result_{i}').value)
        if result != expected_chars[i]:
            raise TestFailure(f"Char {i}: expected {chr(expected_chars[i])} ({expected_chars[i]:02X}) got {chr(result)} ({result:02X})")
    
    dut._log.info("Test 4 passed: 'AbCdEfGh' -> 'aBcDeFgH'")

@cocotb.test(timeout_time=1, timeout_unit="ms")
async def test_flip_case_all_non_alpha(dut):
    """Test all non-alphabetic characters remain unchanged"""
    
    # Input: '!@#$%^&*'
    input_str = '!@#$%^&*'
    expected_str = '!@#$%^&*'
    
    input_chars = [ord(c) for c in input_str]
    expected_chars = [ord(c) for c in expected_str]
    
    for i, val in enumerate(input_chars):
        getattr(dut, f'char_{i}').value = val
    
    await Timer(10, units='ns')
    
    for i in range(8):
        if not is_value_defined(getattr(dut, f'result_{i}').value):
            raise TestFailure(f"Output result_{i} is undefined")
        
        result = int(getattr(dut, f'result_{i}').value)
        if result != expected_chars[i]:
            raise TestFailure(f"Char {i}: expected {chr(expected_chars[i])} ({expected_chars[i]:02X}) got {chr(result)} ({result:02X})")
    
    dut._log.info("Test 5 passed: '!@#$%^&*' -> '!@#$%^&*'")
