import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
DATA_WIDTH = 10  # For L and R inputs
RESULT_WIDTH = 32  # For count outputs
CLK_PERIOD_NS = 10
MAX_CYCLES = 100000  # Maximum cycles for the entire computation

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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_digit_product_counter(dut):
    """Main test function."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (L, R, expected_counts)
    # expected_counts is a list of 9 integers for digits 1 to 9
    test_cases = [
        (50, 100, [3, 7, 4, 6, 5, 7, 2, 15, 2]),
        (3, 7, [0, 0, 1, 1, 1, 1, 1, 0, 0]),
    ]
    
    passed = 0
    failed = 0
    
    for i, (L, R, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: L={L}, R={R}")
        
        try:
            # Set inputs
            dut.L.value = clamp_to_width(L, DATA_WIDTH)
            dut.R.value = clamp_to_width(R, DATA_WIDTH)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read counts
            counts = []
            for idx in range(1, 10):
                signal_name = f'count_{idx}'
                if has_signal(dut, signal_name):
                    val = getattr(dut, signal_name).value
                    if is_value_defined(val):
                        counts.append(int(val))
                    else:
                        counts.append(None)
                else:
                    raise TestFailure(f"Signal {signal_name} not found")
            
            # Verify results
            for idx, (actual, exp) in enumerate(zip(counts, expected)):
                if actual is None:
                    raise TestFailure(f"Count {idx+1} is undefined (X/Z)")
                if actual != exp:
                    raise TestFailure(f"Count {idx+1}: expected {exp}, got {actual}")
            
            cocotb.log.info(f"  PASS: all counts match")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")