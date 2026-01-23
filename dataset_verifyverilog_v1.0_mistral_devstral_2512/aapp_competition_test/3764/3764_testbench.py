import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
DATA_WIDTH = 10
ARRAY_SIZE = 8
K_WIDTH = 4
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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_ranger_strength(dut):
    """Main test function for ranger_strength module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (n, k, x, array, expected_max, expected_min)
    test_cases = [
        # Example 1: n=5, k=1, x=2, arr=[9,7,11,15,5] -> max=13, min=7
        (5, 1, 2, [9,7,11,15,5], 13, 7),
        # Example 2: n=2, k=2, x=569, arr=[605,986] -> max=986, min=605
        (2, 2, 569, [605,986], 986, 605),
        # Example 3: n=10, k=10, x=98, arr=[1,58,62,71,55,4,20,17,25,29] -> max=127, min=17
        (10, 10, 98, [1,58,62,71,55,4,20,17,25,29], 127, 17),
        # Additional test cases
        (1, 1, 1, [1], 1, 1),  # Single element
        (2, 1, 5, [1,2], 7, 2),  # Small array
        (8, 8, 100, [0,2,2,2,3,1,1,1], 4, 0),  # All values
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, k, x, arr_vals, expected_max, expected_min) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, k={k}, x={x}, arr={arr_vals}")
        
        try:
            # Set inputs
            dut.n.value = n
            dut.k.value = k
            dut.x.value = x
            
            # Set array elements (pad to 8 elements with 0)
            padded_arr = arr_vals + [0] * (8 - len(arr_vals))
            for idx, val in enumerate(padded_arr):
                port_name = f"arr_{idx}"
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
                else:
                    raise TestFailure(f"Signal {port_name} not found")
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read outputs
            if not is_value_defined(dut.max_out.value) or not is_value_defined(dut.min_out.value):
                raise TestFailure(f"Output is undefined (X/Z)")
            
            max_result = int(dut.max_out.value)
            min_result = int(dut.min_out.value)
            
            # Verify results
            if max_result != expected_max or min_result != expected_min:
                raise TestFailure(f"Expected (max={expected_max}, min={expected_min}), got (max={max_result}, min={min_result})")
            
            cocotb.log.info(f"  PASS: max={max_result}, min={min_result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
