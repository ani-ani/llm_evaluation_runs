import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 16
N_WIDTH = 4
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

async def start_computation(dut, n_val):
    """Start computation with given n value."""
    dut.n_in.value = clamp_to_width(n_val, N_WIDTH)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_binary_seq_counter(dut):
    """Test binary sequence counter module."""
    
    # Verify sequential interface
    if not has_signal(dut, 'clk'):
        raise TestFailure("DUT missing 'clk' signal - sequential module required")
    
    if not has_signal(dut, 'rst_n'):
        raise TestFailure("DUT missing 'rst_n' signal")
    
    if not has_signal(dut, 'start'):
        raise TestFailure("DUT missing 'start' signal")
    
    if not has_signal(dut, 'n_in'):
        raise TestFailure("DUT missing 'n_in' signal")
    
    if not has_signal(dut, 'result'):
        raise TestFailure("DUT missing 'result' signal")
    
    if not has_signal(dut, 'done'):
        raise TestFailure("DUT missing 'done' signal")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut, cycles=3)
    
    # Test cases: (n, expected_result, description)
    test_cases = [
        (1, 2, "n=1: sequences of length 2, balanced sums"),
        (2, 6, "n=2: sequences of length 4, balanced sums"),
        (3, 20, "n=3: sequences of length 6, balanced sums"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, expected, description) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {description}")
        
        try:
            # Start computation
            await start_computation(dut, n_val)
            
            # Wait for done
            await wait_for_done(dut, max_cycles=50)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            dut._log.info(f"  PASS: n={n_val}, result={result}")
            passed += 1
            
            # Wait one cycle to ensure done is single-cycle
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                raise TestFailure(f"done signal still high after result cycle")
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")