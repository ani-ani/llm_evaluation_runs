import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_N = 8
DATA_WIDTH = 32
MOD = 1000000007
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
# TESTBENCH HELPER FUNCTIONS
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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# EXPECTED RESULT COMPUTATION
# ============================================================================

def compute_expected(coords):
    """Compute expected result using the gap formula."""
    arr = sorted(coords)
    n = len(arr)
    result = 0
    for i in range(n - 1):
        gap = arr[i+1] - arr[i]
        left = (pow(2, i+1, MOD) - 1) % MOD
        right = (pow(2, n-i-1, MOD) - 1) % MOD
        result = (result + gap * left * right) % MOD
    return result

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_subset_sum_calculator(dut):
    """Test the subset sum calculator module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (description, coordinates)
    # Coordinates will be sorted and scaled to fit MAX_N
    test_cases = [
        ("n=2: [4,7]", [4, 7]),
        ("n=3: [4,3,1]", [4, 3, 1]),
        ("n=4: [1,2,3,4]", [1, 2, 3, 4]),
        ("n=5: [4,7,13,17,18]", [4, 7, 13, 17, 18]),
        ("n=1: [7]", [7]),
        ("n=2: [1,1000000000]", [1, 1000000000]),
        ("n=3: [999999998,999999999,999999992]", [999999998, 999999999, 999999992]),
        ("n=3: [465343471,465343474,465343473]", [465343471, 465343474, 465343473]),
        ("n=5: [3,17,2,5,4]", [3, 17, 2, 5, 4]),
        ("n=5: [9,10,7,4,5]", [9, 10, 7, 4, 5]),
    ]
    
    passed = 0
    failed = 0
    
    for desc, coords in test_cases:
        # Compute expected
        expected = compute_expected(coords)
        n = len(coords)
        
        # Sort and prepare array
        sorted_coords = sorted(coords)
        padded = sorted_coords + [0] * (MAX_N - n)
        
        # Write array elements individually
        for i in range(MAX_N):
            dut.arr[i].value = clamp_to_width(padded[i], DATA_WIDTH)
        
        # Set length
        dut.len.value = n
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut, 100)
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"FAIL: {desc} - Result is undefined (X/Z)")
            failed += 1
            continue
        
        result = int(dut.result.value)
        
        # Verify
        if result != expected:
            cocotb.log.error(f"FAIL: {desc} - Expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"PASS: {desc} - Result = {result}")
            passed += 1
        
        # Wait for idle before next test
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
