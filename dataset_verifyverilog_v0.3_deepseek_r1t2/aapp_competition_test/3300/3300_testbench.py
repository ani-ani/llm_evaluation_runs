import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS - COPY THESE EXACTLY
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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
SCALE = 256.0
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

# ============================================================================
# EXPECTED MINIMUM PACK LENGTH CALCULATION (high precision)
# ============================================================================

def expected_min_pack_length(t_list, v_list):
    """Compute minimum pack length using ternary search on float."""
    T0 = max(t_list)
    
    def f(T):
        pos = [v_list[i] * (T - t_list[i]) for i in range(3)]
        return max(pos) - min(pos)
    
    lo = float(T0)
    hi = lo + 2.0  # Search up to T0+2 to ensure coverage
    for _ in range(100):
        m1 = lo + (hi - lo) / 3.0
        m2 = hi - (hi - lo) / 3.0
        if f(m1) < f(m2):
            hi = m2
        else:
            lo = m1
    return f((lo + hi) / 2.0)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_cheetah_min_pack(dut):
    """Test the CheetahMinPack module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (t0, t1, t2, v0, v1, v2, description)
    test_cases = [
        ([0, 0, 0], [1, 2, 3], "All t=0, speeds increasing"),
        ([1, 2, 3], [1, 2, 3], "Sequential t and v"),
        ([0, 1, 1], [1, 2, 2], "Two cheetahs same start"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (t_vals, v_vals, desc) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {desc}")
        
        # Set inputs
        dut.t0.value = t_vals[0]
        dut.t1.value = t_vals[1]
        dut.t2.value = t_vals[2]
        dut.v0.value = v_vals[0]
        dut.v1.value = v_vals[1]
        dut.v2.value = v_vals[2]
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > MAX_CYCLES:
                raise TestFailure(f"Timeout waiting for done in test {i+1}")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z) in test {i+1}")
        
        result_scaled = int(dut.result.value)
        result_float = result_scaled / SCALE
        
        # Compute expected
        expected_float = expected_min_pack_length(t_vals, v_vals)
        expected_scaled = int(round(expected_float * SCALE))
        
        # Allow tolerance of 2 scaled units (about 0.0078)
        if abs(result_scaled - expected_scaled) <= 2:
            dut._log.info(f"  PASS: result = {result_float:.4f}, expected = {expected_float:.4f}")
            passed += 1
        else:
            dut._log.error(f"  FAIL: result = {result_float:.4f}, expected = {expected_float:.4f}")
            failed += 1
    
    # Summary
    dut._log.info("="*60)
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")