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
INDEX_WIDTH = 3
MAX_APPS = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_app_installer(dut):
    """Test the AppInstaller module with various test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, c, [(d, s)], expected_max_count, description)
    test_cases = [
        (
            2, 100,
            [(99, 1), (1, 99)],
            2, "Sample 1: both apps installable"
        ),
        (
            2, 100,
            [(500, 1), (1, 500)],
            0, "Sample 2: no apps installable"
        ),
        (
            3, 100,
            [(80, 20), (90, 10), (10, 90)],
            2, "Three apps, max 2 installable"
        ),
        (
            3, 20,
            [(5, 5), (8, 2), (3, 7)],
            3, "Three apps, all installable"
        ),
        (
            1, 50,
            [(30, 30)],
            1, "Single app"
        ),
        (
            4, 100,
            [(50, 50), (60, 40), (30, 70), (80, 20)],
            3, "Four apps, test greedy"
        ),
        (
            5, 100,
            [(100, 1), (99, 2), (98, 3), (97, 4), (96, 5)],
            1, "Many apps, only one fits"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, c, apps, expected_max, description) in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"Input: n={n}, c={c}")
        cocotb.log.info(f"Apps: {apps}")
        cocotb.log.info(f"Expected max count: {expected_max}")
        
        try:
            # Set inputs
            dut.n.value = n
            dut.c.value = clamp_to_width(c, DATA_WIDTH)
            
            # Set app data using individual port assignment (MANDATORY)
            # Initialize all to 0 first
            for j in range(MAX_APPS):
                setattr(dut, f'd_{j}', 0)
                setattr(dut, f's_{j}', 0)
            
            # Set actual app values
            for idx, (d, s) in enumerate(apps):
                if idx < MAX_APPS:
                    setattr(dut, f'd_{idx}', clamp_to_width(d, DATA_WIDTH))
                    setattr(dut, f's_{idx}', clamp_to_width(s, DATA_WIDTH))
            
            # Reset again to ensure clean state
            await reset_dut(dut)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read results
            # Read max_count
            if not is_value_defined(dut.max_count.value):
                raise TestFailure("max_count is undefined (X/Z)")
            
            actual_max = int(dut.max_count.value)
            
            # Read order array
            order = []
            for j in range(MAX_APPS):
                port_name = f'order_{j}'
                if has_signal(dut, port_name):
                    val = getattr(dut, port_name).value
                    if is_value_defined(val):
                        order.append(int(val))
                    else:
                        order.append(None)
                else:
                    order.append(None)
            
            cocotb.log.info(f"Actual max count: {actual_max}")
            cocotb.log.info(f"Order: {order[:actual_max]}")
            
            # Verify max count
            if actual_max != expected_max:
                raise TestFailure(f"Max count mismatch: expected {expected_max}, got {actual_max}")
            
            # Verify order is valid for the computed count
            if actual_max > 0:
                # Check that order indices are valid
                valid_indices = set(range(n))
                used_indices = []
                for idx in order[:actual_max]:
                    if idx is None or idx not in valid_indices:
                        raise TestFailure(f"Invalid app index in order: {idx}")
                    if idx in used_indices:
                        raise TestFailure(f"Duplicate app index in order: {idx}")
                    used_indices.append(idx)
                
                # Verify installation feasibility with given order
                sim_space = c
                for app_idx in used_indices:
                    d = apps[app_idx][0]
                    s = apps[app_idx][1]
                    need = max(d, s)
                    if sim_space < need:
                        raise TestFailure(f"Order invalid: app {app_idx+1} needs {need} but have {sim_space}")
                    sim_space -= s
                
                cocotb.log.info(f"Order verification: PASS")
            
            cocotb.log.info(f"Test {i+1}: PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1}: FAIL - {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"FINAL RESULTS: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
