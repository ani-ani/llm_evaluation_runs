import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 4      # 4-bit values for 1-8
ARRAY_SIZE = 8
RESULT_WIDTH = 16
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
# ARRAY ACCESS HELPERS
# ============================================================================

def pack_permutation(values):
    """Pack 8 4-bit values into individual ports."""
    # Values should be 1-indexed as per problem
    return values

async def write_permutation(dut, values):
    """Write permutation to individual ports."""
    # Ensure values are within range and 1-indexed
    for i, val in enumerate(values):
        if i >= ARRAY_SIZE:
            break
        if val < 1 or val > 8:
            raise TestFailure(f"Value {val} out of range 1-8")
        
        # Write to p_0, p_1, ...
        port_name = f'p_{i}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
        else:
            raise TestFailure(f"Port {port_name} not found")

async def read_result(dut):
    """Read result signals."""
    if not is_value_defined(dut.min_deviation.value):
        raise TestFailure("min_deviation is undefined (X/Z)")
    if not is_value_defined(dut.best_shift.value):
        raise TestFailure("best_shift is undefined (X/Z)")
    
    min_dev = int(dut.min_deviation.value)
    best_shift = int(dut.best_shift.value)
    return min_dev, best_shift

# ============================================================================
# SEQUENTIAL MODULE HELPERS
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

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# TEST IMPLEMENTATION
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_permutation_shift_optimizer(dut):
    """Test the PermutationShiftOptimizer module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (permutation, n, expected_min_deviation, expected_shift, description)
    test_cases = [
        ([1, 2, 3], 3, 0, 0, "Identity permutation"),
        ([2, 3, 1], 3, 0, 1, "Shift to identity"),
        ([3, 2, 1], 3, 2, 1, "Two solutions, pick one"),
        ([1, 2], 2, 0, 0, "Two elements identity"),
        ([2, 1], 2, 0, 1, "Two elements swap"),
        ([1, 2, 3, 4], 4, 0, 0, "4-element identity"),
        ([4, 3, 2, 1], 4, 4, 1, "4-element reverse"),
        ([2, 1, 4, 3], 4, 0, 2, "4-element double swap"),
        ([1, 3, 2, 4], 4, 2, 0, "4-element single swap"),
        ([1, 2, 3, 4, 5], 5, 0, 0, "5-element identity"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (perm, n, exp_dev, exp_shift, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Permutation: {perm}, n={n}")
        cocotb.log.info(f"  Expected: deviation={exp_dev}, shift={exp_shift}")
        
        try:
            # Write n
            dut.n.value = n
            
            # Write permutation (need 8 values, pad with 1s if needed)
            full_perm = perm + [1] * (8 - len(perm))
            await write_permutation(dut, full_perm)
            
            # Wait a couple cycles for inputs to stabilize
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read results
            min_dev, best_shift = await read_result(dut)
            
            # Verify results
            if min_dev != exp_dev or best_shift != exp_shift:
                raise TestFailure(
                    f"Mismatch: got deviation={min_dev}, shift={best_shift}; "
                    f"expected deviation={exp_dev}, shift={exp_shift}"
                )
            
            cocotb.log.info(f"  PASS: deviation={min_dev}, shift={best_shift}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")

# ============================================================================
# ADDITIONAL TESTS FOR EDGE CASES
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases and boundary conditions."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Edge cases: minimal n and maximal n (for our scaled problem)
    edge_cases = [
        ([1, 2], 2, 0, 0, "Minimal n=2 identity"),
        ([2, 1], 2, 0, 1, "Minimal n=2 swap"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 8, 0, 0, "Maximal n=8 identity"),
        ([8, 7, 6, 5, 4, 3, 2, 1], 8, 28, 1, "Maximal n=8 reverse"),
        ([1, 8, 2, 7, 3, 6, 4, 5], 8, 14, 3, "Maximal n=8 mixed"),
    ]
    
    for i, (perm, n, exp_dev, exp_shift, description) in enumerate(edge_cases):
        cocotb.log.info(f"\nEdge Test {i+1}: {description}")
        
        try:
            dut.n.value = n
            await write_permutation(dut, perm)
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            await start_computation(dut)
            await wait_for_done(dut)
            min_dev, best_shift = await read_result(dut)
            
            if min_dev != exp_dev or best_shift != exp_shift:
                raise TestFailure(
                    f"Edge case failed: got ({min_dev}, {best_shift}), "
                    f"expected ({exp_dev}, {exp_shift})"
                )
            
            cocotb.log.info(f"  PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            raise
        
        await reset_dut(dut)
