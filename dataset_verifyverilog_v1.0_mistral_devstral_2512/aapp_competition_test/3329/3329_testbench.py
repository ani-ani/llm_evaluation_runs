import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
DATA_WIDTH = 6          # N = 6 for our scaled problem
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def string_to_bits(s):
    """Convert string 'B'/'W' to bit vector (B=0, W=1)."""
    return sum((1 << i) if s[i] == 'W' else 0 for i in range(len(s)))

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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_pebble_counter(dut):
    """Test the pebble counter with sample inputs."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (N, K, target_string, expected_count)
    # Note: We'll test N=3,K=1 by mapping to 6-bit space (padded with zeros)
    # and N=6,K=2 directly
    test_cases = [
        (3, 1, "BBW", 2),  # N=3, K=1, target=BBW, expected=2
        (6, 2, "WBWWBW", 3),  # N=6, K=2, target=WBWWBW, expected=3
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (N, K, target_str, expected) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx+1}: N={N}, K={K}, target={target_str}")
        
        try:
            # Convert target to bits
            target_bits = string_to_bits(target_str)
            
            # For N=3 case, we need to handle differently since our module is N=6
            # We'll pad the target to 6 bits but only use first 3 bits for comparison
            # However, since the module expects N=6, we need to adjust
            # For simplicity, we'll test only the N=6 case in this bench
            # and note that N=3 would need a parameterized version
            
            if N != DATA_WIDTH:
                cocotb.log.warning(f"Skipping N={N} case (module configured for N={DATA_WIDTH})")
                continue
            
            # Set parameters
            dut.target.value = target_bits
            dut.K.value = K
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")