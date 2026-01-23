import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY WRITE HELPER
# ============================================================================

def write_array_values(dut, values):
    """Write array values to individual ports."""
    port_names = ['arr_0', 'arr_1', 'arr_2', 'arr_3', 'arr_4', 'arr_5', 'arr_6', 'arr_7']
    for i, val in enumerate(values):
        if i < 8:  # We support up to 8 elements
            if has_signal(dut, port_names[i]):
                setattr(dut, port_names[i], clamp_to_width(val, 8))

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_chocolate_division(dut):
    """Test the chocolate division module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, array_values, expected_result, description)
    test_cases = [
        (3, [4, 8, 5, 0, 0, 0, 0, 0], 9, "Example 1: 4,8,5 -> 9"),
        (5, [3, 10, 2, 1, 5, 0, 0, 0], 2, "Example 2: 3,10,2,1,5 -> 2"),
        (4, [0, 5, 15, 10, 0, 0, 0, 0], 0, "Example 3: Already divisible by 5"),
        (1, [1, 0, 0, 0, 0, 0, 0, 0], 65535, "Example 4: n=1, value=1 -> -1"),
        (3, [0, 0, 17, 0, 0, 0, 0, 0], 0, "Single non-zero divisible by 17"),
        (3, [0, 0, 1, 0, 0, 0, 0, 0], 65535, "Single non-zero=1 -> -1"),
        (1, [21, 0, 0, 0, 0, 0, 0, 0], 0, "Single box with multiple chocolates"),
        (8, [3, 3, 3, 5, 6, 9, 3, 1], 90, "Many values"),
    ]
    
    passed = 0
    failed = 0
    
    for n, values, expected, description in test_cases:
        cocotb.log.info(f"Test: {description}")
        
        # Write inputs
        dut.n.value = n
        write_array_values(dut, values)
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done = False
        for _ in range(1000):  # Max 1000 cycles
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            cocotb.log.error(f"  FAIL: Timeout waiting for done")
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"  FAIL: Result is undefined")
            failed += 1
            continue
        
        result = int(dut.result.value)
        
        # Handle -1 case (0xFFFF in unsigned 16-bit)
        if expected == 65535:
            if result == 65535:
                cocotb.log.info(f"  PASS: Got -1 as expected")
                passed += 1
            else:
                cocotb.log.error(f"  FAIL: Expected -1 (65535), got {result}")
                failed += 1
        else:
            if result == expected:
                cocotb.log.info(f"  PASS: result = {result}")
                passed += 1
            else:
                cocotb.log.error(f"  FAIL: Expected {expected}, got {result}")
                failed += 1
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
