import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
N_MAX = 16          # Must match HDL parameter
DATA_WIDTH = 16     # Must match HDL parameter
CLK_PERIOD_NS = 10
MAX_CYCLES = 50000  # Allow enough cycles for worst-case combinations

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

async def write_tube_array(dut, values):
    """Write tube values to the input array, handling individual elements."""
    # Ensure we don't exceed N_MAX
    if len(values) > N_MAX:
        raise TestFailure(f"Too many tube values: {len(values)} > N_MAX {N_MAX}")
    
    # Write each element individually
    for i in range(N_MAX):
        if i < len(values):
            dut.tubes[i].value = clamp_to_width(values[i], DATA_WIDTH)
        else:
            dut.tubes[i].value = 0

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_vacuum_tube_solver(dut):
    """Test the vacuum tube solver module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (L1, L2, N, tubes_list, expected_possible, expected_max_sum, description)
    test_cases = [
        (
            1000, 2000, 7,
            [100, 480, 500, 550, 1000, 1400, 1500],
            True, 2930,
            "Sample 1: 2930 mm"
        ),
        (
            200, 300, 6,
            [100, 100, 200, 200, 300, 300],
            False, 0,
            "Sample 2: Impossible"
        ),
        (
            500, 500, 4,
            [100, 200, 300, 400],
            True, 1000,
            "Small case: 100+400=500, 200+300=500, total 1000"
        ),
        (
            1000, 1000, 5,
            [500, 600, 700, 800, 900],
            False, 0,
            "Five tubes: all pairs exceed 1000"
        ),
        (
            1000, 1000, 8,
            [100, 200, 300, 400, 500, 600, 700, 800],
            True, 2000,
            "Eight tubes: 200+800=1000 and 300+700=1000, total 2000"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (L1_val, L2_val, N_val, tubes_list, exp_possible, exp_sum, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  L1={L1_val}, L2={L2_val}, N={N_val}, tubes={tubes_list}")
        
        try:
            # Write inputs
            dut.L1.value = L1_val
            dut.L2.value = L2_val
            dut.N.value = N_val
            
            await write_tube_array(dut, tubes_list)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            if not is_value_defined(dut.possible.value):
                raise TestFailure("Possible signal is undefined (X/Z)")
            
            if not is_value_defined(dut.max_sum.value):
                raise TestFailure("Max_sum signal is undefined (X/Z)")
            
            possible_val = int(dut.possible.value)
            max_sum_val = int(dut.max_sum.value)
            
            # Verify
            if possible_val != exp_possible:
                raise TestFailure(f"Possible mismatch: expected {exp_possible}, got {possible_val}")
            
            if possible_val and max_sum_val != exp_sum:
                raise TestFailure(f"Max_sum mismatch: expected {exp_sum}, got {max_sum_val}")
            
            # Log result
            if possible_val:
                cocotb.log.info(f"  PASS: Possible, max_sum={max_sum_val}")
            else:
                cocotb.log.info(f"  PASS: Impossible as expected")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
