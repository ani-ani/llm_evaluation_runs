import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 3
LEN_WIDTH = 4
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

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    
    for _ in range(2):
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

async def write_sublists(dut, sublists, lengths):
    """Write sublists and their lengths to DUT."""
    # Write sublist_0, sublist_1, sublist_2
    for i in range(ARRAY_SIZE):
        if i < len(sublists):
            val = sublists[i]
            port_name = f"sublist_{i}"
            len_port_name = f"sublist_len_{i}"
            
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
            if has_signal(dut, len_port_name):
                getattr(dut, len_port_name).value = clamp_to_width(lengths[i], LEN_WIDTH)
    
    # Write number of valid sublists
    if has_signal(dut, 'num_sublists'):
        dut.num_sublists.value = clamp_to_width(len(sublists), LEN_WIDTH)

async def read_output(dut):
    """Read max sublist and its length from DUT."""
    max_sublist = None
    max_len = None
    
    if is_value_defined(dut.max_sublist_out.value):
        max_sublist = int(dut.max_sublist_out.value)
    
    if is_value_defined(dut.max_len_out.value):
        max_len = int(dut.max_len_out.value)
    
    return max_sublist, max_len

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_length_finder(dut):
    """Test the max_length_finder module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    # Each test case: (sublists as integers, lengths, expected_max_sublist, expected_max_len, description)
    # Sublists are represented as single byte values for simplicity
    # In real scenario, each sublist would be a string up to 8 chars
    # Here we use the length to determine which sublist is longest
    
    test_cases = [
        # Test 1: [['A'],['A','B'],['A','B','C']] -> ['A','B','C'] (len 3)
        # Representing: sublists = [65, 66, 67], lengths = [1, 2, 3]
        ([65, 66, 67], [1, 2, 3], 67, 3, "Test 1: List lengths 1,2,3 -> max length 3"),
        
        # Test 2: [[1],[1,2],[1,2,3]] -> [1,2,3] (len 3)
        ([1, 2, 3], [1, 2, 3], 3, 3, "Test 2: List lengths 1,2,3 -> max length 3"),
        
        # Test 3: [[1,1],[1,2,3],[1,5,6,1]] -> [1,5,6,1] (len 4)
        # Representing: sublists = [1, 2, 3], lengths = [2, 3, 4]
        ([1, 2, 3], [2, 3, 4], 3, 4, "Test 3: List lengths 2,3,4 -> max length 4"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (sublists, lengths, expected_sublist, expected_len, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Write inputs
            await write_sublists(dut, sublists, lengths)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read outputs
            max_sublist, max_len = await read_output(dut)
            
            # Verify
            if max_len is None or max_sublist is None:
                raise TestFailure(f"Output is undefined")
            
            if max_len != expected_len:
                raise TestFailure(f"Expected max_len={expected_len}, got {max_len}")
            
            if max_sublist != expected_sublist:
                raise TestFailure(f"Expected max_sublist={expected_sublist}, got {max_sublist}")
            
            cocotb.log.info(f"  PASS: max_sublist={max_sublist}, max_len={max_len}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")