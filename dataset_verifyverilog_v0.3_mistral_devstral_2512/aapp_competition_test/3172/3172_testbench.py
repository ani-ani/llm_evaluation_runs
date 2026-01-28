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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# Fixed-point conversion helpers (Q16.16)
FRAC_BITS = 16

def float_to_fixed(f):
    return int(f * (1 << FRAC_BITS))

def fixed_to_float(fixed):
    return fixed / (1 << FRAC_BITS)

# ============================================================================
# ARRAY WRITE HELPERS
# ============================================================================

async def write_array_fixed(dut, array_name, values, size):
    """Write fixed-point values to array elements."""
    for i in range(size):
        fixed_val = float_to_fixed(values[i])
        if has_signal(dut, f'{array_name}_{i}'):
            getattr(dut, f'{array_name}_{i}').value = fixed_val
        else:
            getattr(dut, array_name)[i].value = fixed_val

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_fruit_slicer(dut):
    """Test fruit slicer with scaled inputs."""
    
    # Configuration
    CLK_PERIOD_NS = 10
    MAX_N = 8
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, x_list, y_list, expected_max)
    test_cases = [
        (5, [1.00, 3.00, 4.00, 6.00, 7.00], [5.00, 3.00, 2.00, 4.50, 1.00], 4),
        (3, [-1.50, 1.50, 0.00], [-1.00, -1.00, 1.00], 3),
        (2, [1.00, 1.00], [1.00, 1.00], 2),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, x_vals, y_vals, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: n={n}, expected={expected}")
        
        # Write n
        dut.n.value = n
        
        # Write coordinates as fixed-point
        for j in range(n):
            dut.x[j].value = float_to_fixed(x_vals[j])
            dut.y[j].value = float_to_fixed(y_vals[j])
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 1000
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f"Timeout waiting for done")
        
        # Read result
        if not is_value_defined(dut.max_count.value):
            raise TestFailure(f"Result is undefined")
        
        result = int(dut.max_count.value)
        
        if result == expected:
            dut._log.info(f"  PASS: result={result}")
            passed += 1
        else:
            dut._log.error(f"  FAIL: expected={expected}, got={result}")
            failed += 1
    
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")