import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
N_WIDTH = 10
K_WIDTH = 4
RESULT_WIDTH = 30
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

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
# TEST HELPERS
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
async def test_house_puzzle(dut):
    """Test house puzzle module."""
    
    # Verify DUT has required signals
    required_signals = ['clk', 'rst_n', 'start', 'n', 'k', 'result', 'done']
    for sig in required_signals:
        if not has_signal(dut, sig):
            raise TestFailure(f"DUT missing required signal: {sig}")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, k, expected_result)
    MOD = 1000000007
    test_cases = [
        (5, 2, (pow(2, 1, MOD) * pow(3, 3, MOD)) % MOD),
        (7, 4, (pow(4, 3, MOD) * pow(3, 3, MOD)) % MOD),
        (8, 5, (pow(5, 4, MOD) * pow(3, 3, MOD)) % MOD),
        (8, 1, (pow(1, 0, MOD) * pow(7, 7, MOD)) % MOD),
        (10, 7, (pow(7, 6, MOD) * pow(3, 3, MOD)) % MOD),
        (12, 8, (pow(8, 7, MOD) * pow(4, 4, MOD)) % MOD),
        (50, 2, (pow(2, 1, MOD) * pow(48, 48, MOD)) % MOD),
        (100, 8, (pow(8, 7, MOD) * pow(92, 92, MOD)) % MOD),
        (1000, 8, (pow(8, 7, MOD) * pow(992, 992, MOD)) % MOD),
        (999, 7, (pow(7, 6, MOD) * pow(992, 992, MOD)) % MOD),
        (685, 7, (pow(7, 6, MOD) * pow(678, 678, MOD)) % MOD),
        (975, 8, (pow(8, 7, MOD) * pow(967, 967, MOD)) % MOD),
        (475, 5, (pow(5, 4, MOD) * pow(470, 470, MOD)) % MOD),
        (227, 6, (pow(6, 5, MOD) * pow(221, 221, MOD)) % MOD),
        (876, 8, (pow(8, 7, MOD) * pow(868, 868, MOD)) % MOD),
        (1000, 1, (pow(1, 0, MOD) * pow(999, 999, MOD)) % MOD),
        (1000, 2, (pow(2, 1, MOD) * pow(998, 998, MOD)) % MOD),
        (1000, 3, (pow(3, 2, MOD) * pow(997, 997, MOD)) % MOD),
        (1000, 4, (pow(4, 3, MOD) * pow(996, 996, MOD)) % MOD),
        (1000, 5, (pow(5, 4, MOD) * pow(995, 995, MOD)) % MOD),
        (1000, 6, (pow(6, 5, MOD) * pow(994, 994, MOD)) % MOD),
        (657, 3, (pow(3, 2, MOD) * pow(654, 654, MOD)) % MOD),
        (137, 5, (pow(5, 4, MOD) * pow(132, 132, MOD)) % MOD),
        (8, 8, (pow(8, 7, MOD) * pow(0, 0, MOD)) % MOD),
        (9, 8, (pow(8, 7, MOD) * pow(1, 1, MOD)) % MOD),
        (1, 1, (pow(1, 0, MOD) * pow(0, 0, MOD)) % MOD),
        (2, 1, (pow(1, 0, MOD) * pow(1, 1, MOD)) % MOD),
        (2, 2, (pow(2, 1, MOD) * pow(0, 0, MOD)) % MOD),
        (3, 3, (pow(3, 2, MOD) * pow(0, 0, MOD)) % MOD),
        (473, 4, (pow(4, 3, MOD) * pow(469, 469, MOD)) % MOD),
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_n, test_k, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={test_n}, k={test_k}, expected={expected}")
        
        try:
            # Clamp inputs to width
            n_val = clamp_to_width(test_n, N_WIDTH)
            k_val = clamp_to_width(test_k, K_WIDTH)
            
            # Set inputs
            dut.n.value = n_val
            dut.k.value = k_val
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
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