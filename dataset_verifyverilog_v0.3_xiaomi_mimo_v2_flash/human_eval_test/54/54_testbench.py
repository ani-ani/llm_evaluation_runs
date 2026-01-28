import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper function to check if value is defined (not X/Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper function to convert string to byte array
def str_to_bytes(s, length=8):
    """Convert string to fixed-length byte array (ASCII values)."""
    result = [ord(c) for c in s]
    # Pad with zeros if shorter than length
    while len(result) < length:
        result.append(0)
    # Truncate if longer
    return result[:length]

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_same_chars(dut):
    """Test the same_chars module with various string pairs."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (s0, s1, expected_result, description)
    test_cases = [
        ('eabcdzzzz', 'dddzzzzzzzddeddabc', True, 'same unique chars, different frequencies'),
        ('abcd', 'dddddddabc', True, 'one subset of other'),
        ('dddddddabc', 'abcd', True, 'reverse of above'),
        ('eabcd', 'dddddddabc', False, 'extra char e in s0'),
        ('abcd', 'dddddddabcf', False, 'extra char f in s1'),
        ('eabcdzzzz', 'dddzzzzzzzddddabc', False, 'missing char e in s1'),
        ('aabb', 'aaccc', False, 'different sets - b vs c'),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (s0_str, s1_str, expected, desc) in enumerate(test_cases):
        dut._log.info(f"\nTest {i+1}/{total}: {desc}")
        dut._log.info(f"  s0='{s0_str}', s1='{s1_str}', expected={expected}")
        
        # Convert strings to byte arrays
        s0_bytes = str_to_bytes(s0_str, 8)
        s1_bytes = str_to_bytes(s1_str, 8)
        
        dut._log.info(f"  s0_bytes={s0_bytes}")
        dut._log.info(f"  s1_bytes={s1_bytes}")
        
        # Assign values to input arrays
        # Array interface: dut.s0[0:7] and dut.s1[0:7]
        for j in range(8):
            dut.s0[j].value = s0_bytes[j]
            dut.s1[j].value = s1_bytes[j]
        
        # Wait for next clock edge and pulse start
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (max 20 cycles)
        done_received = False
        for cycle in range(20):
            await RisingEdge(dut.clk)
            
            if not is_value_defined(dut.done.value):
                continue
            
            if dut.done.value == 1:
                done_received = True
                break
        
        if not done_received:
            raise TestFailure(f"Test {i+1}: Done signal not asserted after 20 cycles")
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result has undefined value (X/Z)")
        
        actual_result = bool(int(dut.result.value))
        
        if actual_result == expected:
            dut._log.info(f"  Result: {actual_result} [PASS]")
            passed += 1
        else:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {actual_result}")
        
        # Small delay before next test
        await Timer(50, units="ns")
    
    dut._log.info(f"\n=== Summary: {passed}/{total} tests passed ===")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
