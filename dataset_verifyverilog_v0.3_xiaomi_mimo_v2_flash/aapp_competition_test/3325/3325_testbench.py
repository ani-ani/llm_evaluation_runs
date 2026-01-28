import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 32
FRAC_BITS = 16
COORD_WIDTH = 12
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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_vertices(dut, N, x_coords, y_coords):
    """Write x and y coordinates to individual ports."""
    for i in range(8):
        if i < N:
            # x_i
            port_name = f'x{i}'
            if has_signal(dut, port_name):
                val = clamp_to_width(from_signed(x_coords[i], COORD_WIDTH), COORD_WIDTH)
                getattr(dut, port_name).value = val
            # y_i
            port_name = f'y{i}'
            if has_signal(dut, port_name):
                val = clamp_to_width(from_signed(y_coords[i], COORD_WIDTH), COORD_WIDTH)
                getattr(dut, port_name).value = val
        else:
            # Set unused to 0
            for prefix in ['x', 'y']:
                port_name = f'{prefix}{i}'
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = 0

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_water_height(dut):
    """Test the water height calculator."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test case 1: Rectangle from sample input
    N = 4
    D = 30
    L = 50
    x_coords = [20, 100, 100, 20]  # bottom-left, bottom-right, top-right, top-left
    y_coords = [0, 0, 40, 40]
    
    # Expected water height (from Python solution)
    # For rectangle: width = 80, area_up_to_h = 80 * h
    # Volume = D * area = 30 * 80 * h = 2400 * h cm³
    # Water volume = 50 * 1000 = 50000 cm³
    # h = 50000 / 2400 = 20.833333... cm
    expected_h = 20.8333333333
    expected_h_fixed = int(round(expected_h * (1 << FRAC_BITS)))
    
    # Write inputs
    dut.N.value = N
    dut.D.value = D
    dut.L.value = L
    await write_vertices(dut, N, x_coords, y_coords)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    # Read output
    if not is_value_defined(dut.h.value):
        raise TestFailure("Output h is undefined (X/Z)")
    
    h_actual = int(dut.h.value)
    h_actual_float = h_actual / (1 << FRAC_BITS)
    
    # Compare with tolerance (1 LSB)
    if abs(h_actual - expected_h_fixed) > 1:
        raise TestFailure(f"Expected h={expected_h:.4f}, got {h_actual_float:.4f}")
    
    dut._log.info(f"Test passed: h = {h_actual_float:.4f} cm")
    
    # Test case 2: Second sample (N=9) - would require MAX_N >=9, so we skip for this spec
    # The Verilog module should be extended to support up to 100 vertices for full generality.
    # For demonstration, we only test the first case.
