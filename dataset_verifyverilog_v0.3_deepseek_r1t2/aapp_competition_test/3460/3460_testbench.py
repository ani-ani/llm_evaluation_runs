import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
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
# COMPUTATION FUNCTION (PYTHON)
# ============================================================================

def compute_explosion_count(pos, rad, start):
    """Compute explosion count for a given start index (Python reference)."""
    n = len(pos)
    mask = 1 << start
    iteration = 0
    while iteration < n:  # max n iterations
        new_mask = mask
        for i in range(n):
            if mask & (1 << i):
                for j in range(n):
                    if not (mask & (1 << j)):
                        diff = abs(pos[i] - pos[j])
                        if diff <= rad[i]:
                            new_mask |= (1 << j)
        if new_mask == mask:
            break
        mask = new_mask
        iteration += 1
    # Count bits
    count = 0
    for k in range(n):
        if mask & (1 << k):
            count += 1
    return count

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_exploding_worms(dut):
    """Test the exploding_worms module with multiple test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset DUT
    await reset_dut(dut)
    
    # Define test cases: (positions, radii, description)
    # Positions and radii are lists of 8 values (8-bit signed/unsigned)
    test_cases = [
        (
            [4, -10, -2, 100, 101, 102, 103, 104],  # positions
            [3, 9, 3, 0, 0, 0, 0, 0],               # radii
            "Sample input (padded to 8 cans)"
        ),
        (
            [2, 7, 10, 19, 23, 29, 33, 35],        # first 8 cans from second example
            [2, 7, 1, 3, 12, 8, 1, 17],
            "Second example (first 8 cans)"
        ),
        (
            [0, 5, 10, 15, 20, 25, 30, 35],        # evenly spaced, overlapping
            [3, 3, 3, 3, 3, 3, 3, 3],
            "All overlapping"
        ),
        (
            [-64, -48, -32, -16, 0, 16, 32, 48],   # spread out
            [1, 1, 1, 1, 1, 1, 1, 1],
            "Minimal radii"
        ),
    ]
    
    total_tests = 0
    passed = 0
    failed = 0
    
    for case_idx, (positions, radii, description) in enumerate(test_cases):
        dut._log.info(f"\nTest Case {case_idx+1}: {description}")
        
        # Assign positions and radii to DUT
        for i in range(ARRAY_SIZE):
            pos_val = clamp_to_width(positions[i], DATA_WIDTH)
            rad_val = clamp_to_width(radii[i], DATA_WIDTH)
            
            # Convert signed positions to unsigned representation
            if positions[i] < 0:
                pos_val = from_signed(positions[i], DATA_WIDTH)
            
            getattr(dut, f'pos{i}').value = pos_val
            getattr(dut, f'rad{i}').value = rad_val
        
        # Compute expected results for all start indices
        expected = []
        for start_idx in range(ARRAY_SIZE):
            # For unused cans (radius 0 and far away), we still compute
            expected.append(compute_explosion_count(positions, radii, start_idx))
        
        # Test each start index
        for start_idx in range(ARRAY_SIZE):
            dut._log.info(f"  Testing start_index={start_idx}")
            
            # Set shoot_index
            dut.shoot_index.value = start_idx
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z) for start {start_idx}")
            
            result = int(dut.result.value)
            exp = expected[start_idx]
            
            total_tests += 1
            if result == exp:
                dut._log.info(f"    PASS: result={result}")
                passed += 1
            else:
                dut._log.error(f"    FAIL: expected {exp}, got {result}")
                failed += 1
            
            # Small delay between tests
            await Timer(100, units='ns')
    
    # Summary
    dut._log.info("\n" + "="*50)
    dut._log.info(f"Test Summary: {passed}/{total_tests} passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")