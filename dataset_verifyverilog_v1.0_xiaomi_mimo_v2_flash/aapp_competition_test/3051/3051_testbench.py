import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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
        # Handle signed values
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_FOGS = 8
MAX_NETS = 8
COORD_WIDTH = 16
DAY_WIDTH = 16
CLK_PERIOD_NS = 10

# ============================================================================
# FOG GENERATION HELPER
# ============================================================================

def generate_fogs(originator_params):
    """Generate and sort fogs from originator parameters."""
    fogs = []
    for params in originator_params:
        m, d, l, r, h, dd, dx, dh = params
        for k in range(m):
            day = d + k * dd
            left = l + k * dx
            right = r + k * dx
            height = h + k * dh
            # Ensure valid rectangle
            if height >= 1 and left < right:
                fogs.append((day, left, right, height))
    # Sort by day
    fogs.sort(key=lambda x: x[0])
    return fogs

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_fog_catcher(dut):
    """Test fog catcher with adapted parameters."""
    
    # Check if sequential
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await Timer(20, units='ns')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases: (originator_params, expected_missed)
    test_cases = [
        ([(2, 3, 0, 2, 9, 2, 3, 0), (1, 6, 1, 4, 6, 3, -1, -2)], 3),
        ([(4, 0, 0, 10, 10, 1, 15, 0), (3, 5, 50, 55, 8, 1, -16, 2), (3, 10, 7, 10, 4, 1, 8, -1)], 6),
        ([(7, 0, 0, 20, 10, 3, 0, 10), (10, 1, 0, 2, 5, 2, 2, 7)], 11)
    ]
    
    for test_idx, (originator_params, expected) in enumerate(test_cases):
        dut._log.info(f"Test {test_idx + 1}")
        
        # Generate fogs
        fogs = generate_fogs(originator_params)
        dut._log.info(f"  Generated {len(fogs)} fogs")
        
        if len(fogs) > MAX_FOGS:
            fogs = fogs[:MAX_FOGS]
            dut._log.warning(f"  Truncated to {MAX_FOGS} fogs")
        
        # Load fog data (RULE B2: assign individually)
        for i in range(MAX_FOGS):
            if i < len(fogs):
                day, left, right, height = fogs[i]
                # Clamp values to bit widths
                dut.fog_day[i].value = clamp_to_width(day, DAY_WIDTH)
                dut.fog_left[i].value = clamp_to_width(left, COORD_WIDTH)
                dut.fog_right[i].value = clamp_to_width(right, COORD_WIDTH)
                dut.fog_height[i].value = clamp_to_width(height, COORD_WIDTH)
                dut._log.info(f"  Fog {i}: day={day}, left={left}, right={right}, height={height}")
            else:
                # Clear unused fog slots
                dut.fog_day[i].value = 0
                dut.fog_left[i].value = 0
                dut.fog_right[i].value = 0
                dut.fog_height[i].value = 0
        
        dut.fog_valid_count.value = len(fogs)
        
        # Wait for inputs to stabilize
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout
        max_cycles = 1000
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                dut._log.info(f"  Completed in {cycle + 1} cycles")
                break
        else:
            raise TestFailure(f"Timeout in test {test_idx + 1} after {max_cycles} cycles")
        
        # Read result
        if not is_value_defined(dut.missed_count.value):
            raise TestFailure(f"Undefined result in test {test_idx + 1}")
        
        result = int(dut.missed_count.value)
        
        if result != expected:
            raise TestFailure(f"Test {test_idx + 1}: expected {expected}, got {result}")
        
        dut._log.info(f"  PASS: missed = {result}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info("All tests passed!")