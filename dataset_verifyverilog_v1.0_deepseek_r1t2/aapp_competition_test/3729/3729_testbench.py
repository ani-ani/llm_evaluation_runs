import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS (not needed for this module)
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports (arr_0, arr_1, ...)
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    """Read array values, handling different interface styles."""
    results = []
    
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                results.append(int(arr[i].value))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    
    return results

# ============================================================================
# SEQUENTIAL MODULE HELPERS (not needed for this module)
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# EXPECTED VALUE COMPUTATION
# ============================================================================

def compute_expected(f, w, h):
    """Compute the probability using Python (same logic as original solution)."""
    mod = 1000000007
    if w == 0:
        return 1
    total = math.comb(f + w, w)
    liked = 0
    kmax = min(w // (h + 1), f + 1)
    for k in range(1, kmax + 1):
        term1 = math.comb(f + 1, k)
        n2 = w - k * h - 1
        r2 = k - 1
        if n2 >= r2 and r2 >= 0:
            term2 = math.comb(n2, r2)
        else:
            term2 = 0
        liked += term1 * term2
    inv_total = pow(total, mod - 2, mod)
    return (liked * inv_total) % mod

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_probability(dut):
    """Test the prob_calc module with small inputs."""
    
    # Define test cases: (f, w, h, expected)
    test_cases = [
        (0, 1, 0, 1),          # w=0 -> liked=1, total=1, prob=1
        (1, 0, 0, 1),          # f>0, w=0 -> liked=1, total=1, prob=1
        (1, 1, 1, 0),          # liked=0, total=2, prob=0
        (1, 2, 1, 666666672),  # 2/3 mod MOD
        (2, 2, 1, 500000004),  # 1/2 mod MOD
        (3, 3, 2, 400000003),  # 1/5 mod MOD
    ]
    
    passed = 0
    failed = 0
    
    for i, (f, w, h, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: f={f}, w={w}, h={h}")
        
        # Compute expected using Python
        computed_expected = compute_expected(f, w, h)
        if computed_expected != expected:
            cocotb.log.error(f"  Internal error: computed {computed_expected}, expected {expected}")
            failed += 1
            continue
        
        # Set inputs
        dut.f.value = clamp_to_width(f, 8)
        dut.w.value = clamp_to_width(w, 8)
        dut.h.value = clamp_to_width(h, 8)
        
        # Wait for combinational propagation
        await Timer(10, units='ns')
        
        # Read output
        if not is_value_defined(dut.p.value):
            cocotb.log.error(f"  FAIL: Output is undefined (X/Z)")
            failed += 1
            continue
        
        result = int(dut.p.value)
        
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