import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Match HDL design parameters
# ============================================================================
DATA_WIDTH = 8       # Coordinate width
RESULT_WIDTH = 12    # MST weight result width
N_MAX = 8            # Maximum number of points
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
# CUSTOM ARRAY WRITE HELPER FOR INDIVIDUAL PORTS (x0, x1, ...)
# ============================================================================

def write_individual_ports(dut, prefix, values, width):
    """Write values to individual ports like x0, x1, ... or y0, y1, ..."""
    for i, val in enumerate(values):
        port_name = f"{prefix}{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, width)
        else:
            raise TestFailure(f"Port {port_name} not found in DUT")
    # Set remaining ports to 0
    for i in range(len(values), N_MAX):
        port_name = f"{prefix}{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = 0

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
# TESTBENCH MAIN
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_mst_mht_weight(dut):
    """Test MST Manhattan weight computation for scaled problem."""
    
    # Detect module type
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        # Reset
        await reset_dut(dut)
    
    # Define test cases: (N, x_coords, y_coords, expected_result, description)
    # Test case 1: Sample from problem (4 points)
    # Points: (0,0), (0,1), (1,0), (1,1) -> MST weight = 3
    test_cases = [
        (
            4,                                  # N
            [0, 0, 1, 1],                       # x coordinates
            [0, 1, 0, 1],                       # y coordinates
            3,                                  # Expected MST weight
            "Sample 1: 4 points forming a square"
        ),
        (
            5,                                  # N
            [0, 10, 10, 11, 12],                # x coordinates
            [0, 0, 0, 1, 2],                    # y coordinates
            14,                                 # Expected MST weight
            "Sample 2: 5 points with duplicates"
        ),
        (
            1,                                  # N = 1
            [5],                                 # x
            [7],                                 # y
            0,                                   # Expected: 0 (no edges)
            "Edge case: Single point"
        ),
        (
            2,                                  # N = 2
            [0, 5],                              # x
            [0, 12],                             # y
            17,                                  # Expected: |0-5|+|0-12| = 5+12 = 17
            "Simple case: Two points"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (N, x_coords, y_coords, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  N={N}, expected={expected}")
        
        try:
            # Write N
            if has_signal(dut, 'N'):
                dut.N.value = N
            else:
                raise TestFailure("Signal 'N' not found")
            
            # Write coordinates
            write_individual_ports(dut, 'x', x_coords, DATA_WIDTH)
            write_individual_ports(dut, 'y', y_coords, DATA_WIDTH)
            
            # Wait a cycle for inputs to settle
            if is_sequential:
                await RisingEdge(dut.clk)
            else:
                await Timer(10, units='ns')
            
            # Start computation
            if is_sequential:
                await start_computation(dut)
                await wait_for_done(dut)
                # Result should be ready on same cycle done is high
                await Timer(1, units='ns')  # Small delay for propagation
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Validate result
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  Result: {result} [PASS]")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
