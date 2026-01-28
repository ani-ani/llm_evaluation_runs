import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# ============================================================================
# HELPER FUNCTIONS (from template)
# ============================================================================
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# RESET AND DONE HANDLING
# ============================================================================
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# TESTBENCH
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_gold_scheduler(dut):
    """Test gold scheduler with two test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: each is (list of (t,h) pairs, expected result)
    test_cases = [
        ([(5,8), (5,6), (3,4), (5,13), (6,10)], 3, "Sample 1"),
        ([(5,10), (6,15), (2,7), (3,3), (4,11)], 4, "Sample 2")
    ]
    
    for tcs_idx, (pairs, expected, description) in enumerate(test_cases):
        dut._log.info(f"Running test {tcs_idx+1}: {description}")
        
        # Prepare 8 stores: first len(pairs) are valid, rest invalid
        t_list = []
        h_list = []
        for i in range(8):
            if i < len(pairs):
                t_list.append(pairs[i][0])
                h_list.append(pairs[i][1])
            else:
                t_list.append(255)  # invalid marker
                h_list.append(0)
        
        # Assign inputs
        for i in range(8):
            # Set t_i and h_i
            if has_signal(dut, f't{i}'):
                getattr(dut, f't{i}').value = clamp_to_width(t_list[i], DATA_WIDTH)
                getattr(dut, f'h{i}').value = clamp_to_width(h_list[i], DATA_WIDTH)
            else:
                raise TestFailure(f"Signal t{i} not found")
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Expected {expected}, got {result}")
        
        dut._log.info(f"  PASS: result = {result}")
    
    dut._log.info("All tests passed!")