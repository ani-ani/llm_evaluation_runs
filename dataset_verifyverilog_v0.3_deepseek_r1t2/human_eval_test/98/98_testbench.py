import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_count_upper(dut):
    """Test count_upper module with multiple test cases."""
    
    # Create and start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Helper to wait for done with timeout
    async def wait_for_done(max_cycles=20):
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                return
        raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")
    
    # Test cases: (input_string, expected_count)
    test_cases = [
        ('aBCdEf', 1),
        ('abcdefg', 0),
        ('dBBE', 0),
        ('B', 0),
        ('U', 1),
        ('', 0),
        ('EEEE', 2),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for test_str, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        dut.char_in.value = 0
        dut.length.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Set length and start
        dut.length.value = len(test_str)
        await RisingEdge(dut.clk)
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed characters one by one
        for i, char in enumerate(test_str):
            dut.char_in.value = ord(char)
            await RisingEdge(dut.clk)
        
        # Wait for done
        await wait_for_done(20)
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test '{test_str}': Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Test '{test_str}': expected {expected}, got {result}")
        
        dut._log.info(f"Test '{test_str}': passed (expected={expected}, got={result})")
        passed += 1
        
        # Wait one more cycle before next test
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")
