import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 64
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000  # Enough for 200+ iterations

# ============================================================================
# HELPER FUNCTIONS
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

async def start_computation(dut, a, b):
    """Set inputs and pulse start signal."""
    # Assign inputs
    dut.a_in.value = a
    dut.b_in.value = b
    
    # Pulse start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_resistor_network(dut):
    """Test the resistor network module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (a, b, expected_result)
    test_cases = [
        (1, 1, 1),
        (3, 2, 3),
        (199, 200, 200),
        (1, 1000000000000000000, 1000000000000000000),
        (3, 1, 3),
        (21, 8, 7),
        (18, 55, 21),
        (1, 2, 2),
        (2, 1, 2),
        (1, 3, 3),
        (2, 3, 3),
        (1, 4, 4),
        (5, 2, 4),
        (2, 5, 4),
        (4, 5, 5),
        (3, 5, 4),
        (13, 4, 7),
        (21, 17, 9),
        (5, 8, 5),
        (13, 21, 7),
        (74, 99, 28),
        (2377, 1055, 33),
        (645597, 134285, 87),
        (29906716, 35911991, 92),
        (3052460231, 856218974, 82),
        (288565475053, 662099878640, 88),
        (11504415412768, 12754036168327, 163),
        (9958408561221547, 4644682781404278, 196),
        (60236007668635342, 110624799949034113, 179),
        (4, 43470202936783249, 10867550734195816),
        (16, 310139055712567491, 19383690982035476),
        (15, 110897893734203629, 7393192915613582),
        (439910263967866789, 38, 11576585893891241),
        (36, 316049483082136289, 8779152307837131),
        (752278442523506295, 52, 14466893125452056),
        (4052739537881, 6557470319842, 62),
        (44945570212853, 72723460248141, 67),
        (498454011879264, 806515533049393, 72),
        (8944394323791464, 5527939700884757, 77),
        (679891637638612258, 420196140727489673, 86),
        (1, 923438, 923438),
        (3945894354376, 1, 3945894354376),
        (999999999999999999, 5, 200000000000000004),
        (999999999999999999, 1000000000000000000, 1000000000000000000),
        (999999999999999991, 1000000000000000000, 111111111111111120),
        (999999999999999993, 999999999999999991, 499999999999999998),
        (3, 1000000000000000000, 333333333333333336),
        (1000000000000000000, 3, 333333333333333336),
        (10000000000, 1000000001, 100000019),
        (2, 999999999999999999, 500000000000000001),
        (999999999999999999, 2, 500000000000000001),
        (2, 1000000001, 500000002),
        (123, 1000000000000000000, 8130081300813023),
    ]
    
    passed = 0
    failed = 0
    
    for i, (a, b, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: a={a}, b={b}")
        
        try:
            # Start computation
            await start_computation(dut, a, b)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")