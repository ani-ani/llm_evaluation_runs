import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_module(dut):
    """Main test function."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k.value = 0
    for i in range(8):
        if has_signal(dut, f'arr_{i}'):
            getattr(dut, f'arr_{i}').value = 0
    dut.len.value = 0
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (k, array_values, length, expected_result, description)
    test_cases = [
        (2, [2,2,2,2], 4, 8, "Example 1: k=2, all 2s"),
        (-3, [3,-6,-3,12], 4, 3, "Example 2: k=-3, mixed values"),
        (2, [2,2,2,2,2,2,2,2], 8, 45, "Full 8-element array of 2s"),
        (1, [1,1,1,1], 4, 4, "k=1, all 1s"),
        (-1, [1,-1,1,-1], 4, 10, "k=-1, alternating 1,-1"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (k, arr_vals, length, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        # Set k (convert to signed representation)
        dut.k.value = from_signed(k, 4)
        
        # Set array elements and length
        for j in range(8):
            port_name = f'arr_{j}'
            if has_signal(dut, port_name):
                if j < length:
                    getattr(dut, port_name).value = from_signed(arr_vals[j], 8)
                else:
                    getattr(dut, port_name).value = 0
        dut.len.value = length
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout
        done_seen = False
        for _ in range(1000):  # Max 1000 cycles
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done_seen = True
                break
        
        if not done_seen:
            cocotb.log.error(f"  FAIL: Timeout waiting for done")
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"  FAIL: Result is undefined")
            failed += 1
            continue
        
        result = int(dut.result.value)
        
        if result != expected:
            cocotb.log.error(f"  FAIL: Expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")