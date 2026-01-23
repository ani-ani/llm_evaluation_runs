import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
N = 4
MASK_WIDTH = N
SIZE_WIDTH = 3
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
# VERIFICATION HELPERS
# ============================================================================

def compute_distance_sq(x1, y1, x2, y2):
    dx = x1 - x2
    dy = y1 - y2
    return dx*dx + dy*dy

def verify_clique(dut, coordinates, d, mask, max_size):
    """Verify that the output subset is a valid clique of the reported size."""
    # Convert mask to list of indices
    indices = [i for i in range(N) if (mask >> i) & 1]
    if len(indices) != max_size:
        raise TestFailure(f"Mask popcount {len(indices)} != max_size {max_size}")
    if max_size == 0:
        return
    # Check all pairs within distance d
    for i in range(len(indices)):
        for j in range(i+1, len(indices)):
            idx1 = indices[i]
            idx2 = indices[j]
            x1, y1 = coordinates[idx1]
            x2, y2 = coordinates[idx2]
            dist_sq = compute_distance_sq(x1, y1, x2, y2)
            if dist_sq > d*d:
                raise TestFailure(f"Pair ({idx1},{idx2}) distance squared {dist_sq} > {d*d}")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_clique(dut):
    """Test the max_clique module with two test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (n, d, coordinates, expected_max_size, description)
    # Coordinates are list of (x, y) for up to 4 sensors
    test_cases = [
        (
            4, 1, [(0,0), (0,1), (1,0), (1,1)], 2,
            "4 sensors, d=1, expected max clique size 2"
        ),
        (
            3, 10, [(0,0), (0,5), (5,0)], 3,
            "3 sensors, d=10, expected max clique size 3"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for n, d, coords, expected_size, description in test_cases:
        cocotb.log.info(f"\nRunning test: {description}")
        
        try:
            # Set inputs
            dut.num_sensors.value = clamp_to_width(n, 3)
            dut.d.value = clamp_to_width(d, DATA_WIDTH)
            
            # Assign coordinates (for N=4, we have ports x0..x3, y0..y3)
            dut.x0.value = clamp_to_width(coords[0][0], DATA_WIDTH)
            dut.y0.value = clamp_to_width(coords[0][1], DATA_WIDTH)
            if n > 1:
                dut.x1.value = clamp_to_width(coords[1][0], DATA_WIDTH)
                dut.y1.value = clamp_to_width(coords[1][1], DATA_WIDTH)
            else:
                dut.x1.value = 0
                dut.y1.value = 0
            if n > 2:
                dut.x2.value = clamp_to_width(coords[2][0], DATA_WIDTH)
                dut.y2.value = clamp_to_width(coords[2][1], DATA_WIDTH)
            else:
                dut.x2.value = 0
                dut.y2.value = 0
            if n > 3:
                dut.x3.value = clamp_to_width(coords[3][0], DATA_WIDTH)
                dut.y3.value = clamp_to_width(coords[3][1], DATA_WIDTH)
            else:
                dut.x3.value = 0
                dut.y3.value = 0
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            if not is_value_defined(dut.max_size.value):
                raise TestFailure("max_size is undefined")
            if not is_value_defined(dut.subset_mask.value):
                raise TestFailure("subset_mask is undefined")
            
            max_size = int(dut.max_size.value)
            subset_mask = int(dut.subset_mask.value)
            
            cocotb.log.info(f"  Result: max_size={max_size}, subset_mask={subset_mask:04b}")
            
            # Verify
            if max_size != expected_size:
                raise TestFailure(f"Expected size {expected_size}, got {max_size}")
            
            # Additional verification: the subset must be a valid clique
            verify_clique(dut, coords, d, subset_mask, max_size)
            
            cocotb.log.info("  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")