import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 5  # For M, which is up to 16, so 5 bits
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
# INPUT/OUTPUT HELPERS FOR ARRAY PORTS
# ============================================================================

async def set_inputs(dut, len_val, values):
    """Set the len and values inputs for the DUT.
    values should be a list of integers, at least len_val long.
    We will assign to val0, val1, ... val7. Unused values are set to 0.
    """
    # Clamp len to 0..8
    if len_val < 0 or len_val > 8:
        raise ValueError(f"len must be between 0 and 8, got {len_val}")
    
    # Pad values to 8 elements with zeros
    padded_values = values + [0] * (8 - len(values))
    
    # Set each value port
    dut.val0.value = clamp_to_width(padded_values[0], DATA_WIDTH)
    dut.val1.value = clamp_to_width(padded_values[1], DATA_WIDTH)
    dut.val2.value = clamp_to_width(padded_values[2], DATA_WIDTH)
    dut.val3.value = clamp_to_width(padded_values[3], DATA_WIDTH)
    dut.val4.value = clamp_to_width(padded_values[4], DATA_WIDTH)
    dut.val5.value = clamp_to_width(padded_values[5], DATA_WIDTH)
    dut.val6.value = clamp_to_width(padded_values[6], DATA_WIDTH)
    dut.val7.value = clamp_to_width(padded_values[7], DATA_WIDTH)
    
    # Set len
    dut.len.value = len_val

async def read_outputs(dut):
    """Read the outputs M, final_len, and final_queue."""
    M = int(dut.M.value)
    final_len = int(dut.final_len.value)
    final_queue = [
        int(dut.final0.value),
        int(dut.final1.value),
        int(dut.final2.value),
        int(dut.final3.value),
        int(dut.final4.value),
        int(dut.final5.value),
        int(dut.final6.value),
        int(dut.final7.value),
    ]
    return M, final_len, final_queue

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_candidate_simulation(dut):
    """Main test for candidate simulation module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (len, values, expected_M, expected_final_queue)
    # Note: expected_final_queue is a list of values that should be in the final queue.
    # The module outputs all 8 ports, but only the first final_len are valid.
    test_cases = [
        # Case 1: All equal, no one leaves
        (3, [17, 17, 17], 0, [17, 17, 17]),
        # Case 2: Example from problem (adapted to N=7)
        (7, [8, 1, 2, 3, 5, 6, 7], 2, [8]),
        # Case 3: Our adapted case (N=8)
        (8, [3, 6, 2, 3, 2, 2, 2, 1], 3, [6]),
    ]
    
    passed = 0
    failed = 0
    
    for i, (len_val, values, expected_M, expected_final) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: len={len_val}, values={values}")
        
        try:
            # Set inputs
            await set_inputs(dut, len_val, values)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read outputs
            M, final_len, final_queue = await read_outputs(dut)
            
            # Verify M
            if M != expected_M:
                raise TestFailure(f"M mismatch: expected {expected_M}, got {M}")
            
            # Verify final queue
            # The expected_final list should match the first final_len elements of final_queue
            if final_len != len(expected_final):
                raise TestFailure(f"final_len mismatch: expected {len(expected_final)}, got {final_len}")
            
            for j in range(final_len):
                if final_queue[j] != expected_final[j]:
                    raise TestFailure(f"final_queue[{j}] mismatch: expected {expected_final[j]}, got {final_queue[j]}")
            
            cocotb.log.info(f"  PASS: M={M}, final_len={final_len}, final_queue={final_queue[:final_len]}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
