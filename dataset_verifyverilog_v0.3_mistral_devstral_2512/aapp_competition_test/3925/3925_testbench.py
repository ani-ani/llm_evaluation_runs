import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Convert string to packed value and set inputs
async def set_string_input(dut, s):
    packed = 0
    for i, char in enumerate(s):
        if char == 'w':
            packed |= (1 << i)
    dut.string_in.value = packed
    dut.actual_length.value = len(s)

@cocotb.test(timeout_time=500, timeout_unit='ms')
async def test_zebra_max(dut):
    """Test zebra_max module with provided examples"""
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_string, expected_result)
    test_cases = [
        ("bwwwbwwbw", 5),
        ("bwwbwwb", 3),
        ("bwb", 3),
        ("bbbbwbwwbbwwwwwbbbwb", 4),
        ("bw", 2),
        ("b", 1),
        ("w", 1),
        ("bbbbbbwbwb", 5),
        ("wbwb", 4),
        ("bwbw", 4),
        ("wbwbwbwbwbwb", 12),
        ("wbwbwbwbwb", 10),
        ("bwbwbw", 6),
        ("bww", 3),
        ("wbwbwb", 6),
        ("www", 1),
    ]
    
    passed = 0
    failed = 0
    
    for s, expected in test_cases:
        dut._log.info(f"Testing: {s} (expected: {expected})")
        
        # Set inputs
        await set_string_input(dut, s)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout
        cycles = 0
        while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > 100:
                raise TestFailure(f"Timeout waiting for done (>{100} cycles)")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result is undefined")
            
        result = int(dut.result.value)
        
        if result == expected:
            dut._log.info(f"  PASS: result={result}")
            passed += 1
        else:
            dut._log.error(f"  FAIL: expected {expected}, got {result}")
            failed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")