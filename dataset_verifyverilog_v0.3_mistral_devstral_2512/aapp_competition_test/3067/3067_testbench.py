import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_SEQ_LEN = 4
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
async def test_solitaire_merger(dut):
    """Test the solitaire card game merger."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (seq_a, seq_b, expected_output, description)
    # Each sequence: (a0, a1, a2, a3, len_a)
    test_cases = [
        ((2, 0, 0, 0, 1), (100, 0, 0, 0, 1), [2, 100], "Simple: [2] vs [100]"),
        ((10, 20, 30, 40, 4), (28, 27, 0, 0, 2), [10, 20, 28, 27, 30, 40], 
         "Multi-element: [10,20,30,40] vs [28,27]"),
        ((5, 1, 2, 0, 3), (5, 1, 1, 0, 3), [5, 1, 1, 5, 1, 2], 
         "Equal heads: [5,1,2] vs [5,1,1]"),
        ((1, 2, 3, 4, 4), (0, 0, 0, 0, 0), [1, 2, 3, 4], "B empty"),
        ((42, 0, 0, 0, 1), (7, 0, 0, 0, 1), [7, 42], "Single vs single"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (seq_a, seq_b, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Unpack sequences
            a0, a1, a2, a3, len_a = seq_a
            b0, b1, b2, b3, len_b = seq_b
            
            # Set inputs
            dut.a0.value = clamp_to_width(a0, DATA_WIDTH)
            dut.a1.value = clamp_to_width(a1, DATA_WIDTH)
            dut.a2.value = clamp_to_width(a2, DATA_WIDTH)
            dut.a3.value = clamp_to_width(a3, DATA_WIDTH)
            dut.len_a.value = len_a
            
            dut.b0.value = clamp_to_width(b0, DATA_WIDTH)
            dut.b1.value = clamp_to_width(b1, DATA_WIDTH)
            dut.b2.value = clamp_to_width(b2, DATA_WIDTH)
            dut.b3.value = clamp_to_width(b3, DATA_WIDTH)
            dut.len_b.value = len_b
            
            # Start computation
            await start_computation(dut)
            
            # Collect outputs
            results = []
            output_count = 0
            max_output = len_a + len_b
            
            while output_count < max_output:
                await RisingEdge(dut.clk)
                
                if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
                    result_val = int(dut.result.value)
                    results.append(result_val)
                    output_count += 1
                    cocotb.log.info(f"  Output {output_count}: {result_val}")
            
            # Verify results
            if results != expected:
                raise TestFailure(f"Expected {expected}, got {results}")
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")