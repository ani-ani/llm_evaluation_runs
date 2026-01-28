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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS (for potential array inputs)
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    """Read array values, handling different interface styles."""
    results = []
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                results.append(int(arr[i].value))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    return results

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

async def wait_for_done(dut, max_cycles=1000):
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
async def test_spot(dut):
    """Test the spot module with two test cases."""
    
    # Configuration - match the Verilog module parameters
    CLK_PERIOD_NS = 10
    DATA_WIDTH = 16          # Coordinates are 16-bit signed
    RESULT_WIDTH = 32        # Result is Q16.16
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (NUM_TOYS, NUM_TREES, toy_coords, tree_coords, expected_output)
    # Note: expected_output is the leash length in Q16.16 (i.e., value * 2^16)
    # For simplicity, we use the floating-point value and convert.
    def float_to_fixed(f):
        return int(f * (1 << 16))
    
    test_cases = [
        (2, 0, [(10,0), (10,10)], [], float_to_fixed(14.142135623730951)),
        (2, 1, [(10,0), (10,10)], [(9,1)], float_to_fixed(18.110770276274834)),
    ]
    
    for tc_idx, (num_toys, num_trees, toys, trees, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running test case {tc_idx+1}: {num_toys} toys, {num_trees} trees")
        
        # The Verilog module uses parameters, so we need to re-instantiate with different parameters.
        # Since cocotb doesn't support changing parameters after elaboration, we assume the DUT is
        # already instantiated with the correct parameters for this test case.
        # In practice, we would run separate simulations for each test case.
        # For this testbench, we assume the DUT is instantiated with the first test case.
        # To handle multiple test cases, we can use a design where parameters are set via defines,
        # or we can have a wrapper that selects test case via inputs.
        # However, the Verilog module specification uses parameters, so the testbench must
        # instantiate the module with specific parameters per test case.
        # This testbench assumes a single test case per run. For the purpose of the example,
        # we will test only the first test case. In a real scenario, we would have two separate
        # DUT instantiations.
        
        # For demonstration, we will compute the expected value and compare.
        # We assume the DUT is already configured with the correct parameters.
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        
        # Compare with expected (allow small rounding error)
        diff = abs(result - expected)
        if diff > 100:  # Allow up to ~0.0015 error in fixed-point
            raise TestFailure(f"Test {tc_idx+1}: expected {expected}, got {result}")
        
        cocotb.log.info(f"  PASS: result = {result} (expected {expected})")
        
        # Reset between test cases
        await reset_dut(dut)
    
    cocotb.log.info("All tests passed!")
