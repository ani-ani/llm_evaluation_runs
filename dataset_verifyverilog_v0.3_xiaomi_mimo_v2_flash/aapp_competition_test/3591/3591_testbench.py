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
# ADDITIONAL HELPERS
# ============================================================================

def pack_array(values, element_bits=8, size=16):
    """Pack list of values into single integer, LSB first, pad with zeros to size."""
    result = 0
    for i, val in enumerate(values):
        result |= (val & ((1 << element_bits) - 1)) << (i * element_bits)
    return result

def is_photo_valid(heights):
    """Python reference implementation."""
    n = len(heights)
    for i in range(n):
        left_min_above = None
        for j in range(i):
            if heights[j] > heights[i]:
                if left_min_above is None or heights[j] < left_min_above:
                    left_min_above = heights[j]
        if left_min_above is None:
            continue
        for k in range(i+1, n):
            if heights[k] > heights[i] and heights[k] > left_min_above:
                return True
    return False

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_photo_validator(dut):
    """Test the photo_validator module with sample test cases."""
    
    # Detect if sequential
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await Timer(20, units='ns')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases: (length, list_of_heights, expected_result)
    # Expected result: 1 if photo is valid, else 0
    test_cases = [
        (3, [2, 1, 3], 1),          # Sample 1
        (4, [140, 157, 160, 193], 0),  # Photo1
        (5, [15, 24, 38, 9, 30], 1),   # Photo2
        (6, [36, 12, 24, 29, 23, 15], 0),  # Photo3
        (6, [170, 230, 320, 180, 250, 210], 1),  # Photo4
    ]
    
    passed = 0
    failed = 0
    
    for i, (length, heights, expected) in enumerate(test_cases):
        dut._log.info(f"Test case {i+1}: length={length}, heights={heights}")
        
        # Pack the array
        packed = pack_array(heights, element_bits=8, size=16)
        
        # Set inputs
        dut.length.value = length
        dut.packed_arr.value = packed
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        max_cycles = 1000
        done = False
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            dut._log.error(f"Test {i+1}: Timeout waiting for done")
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.result.value):
            dut._log.error(f"Test {i+1}: Result is undefined (X/Z)")
            failed += 1
            continue
        
        result = int(dut.result.value)
        
        if result != expected:
            dut._log.error(f"Test {i+1}: Expected {expected}, got {result}")
            failed += 1
        else:
            dut._log.info(f"Test {i+1}: PASS (result={result})")
            passed += 1
        
        # Reset between tests
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")