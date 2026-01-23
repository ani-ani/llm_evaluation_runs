import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
MAX_N = 8
MAX_STRING_LEN = 8
MAX_COMPOSITE_LEN = 64
CLK_PERIOD_NS = 10

# Helper functions
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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def pack_string(s, max_len=MAX_STRING_LEN):
    """Pack a string into an integer array for Verilog assignment"""
    result = [0] * max_len
    for i, c in enumerate(s[:max_len]):
        result[i] = ord(c)
    return result

def pack_composite_string(s, max_len=MAX_COMPOSITE_LEN):
    """Pack composite string into array"""
    result = [0] * max_len
    for i, c in enumerate(s[:max_len]):
        result[i] = ord(c)
    return result

async def reset_dut(dut):
    """Reset the DUT"""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    """Pulse start signal"""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=10000):
    """Wait for done signal"""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_composite_rank(dut):
    """Test composite rank module"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        {
            'n': 5,
            'k': 3,
            'initial_strings': ['a', 'b', 'c', 'd', 'e'],
            'composite_string': 'cad',
            'expected': 26
        },
        {
            'n': 8,
            'k': 8,
            'initial_strings': ['font', 'lewin', 'darko', 'deon', 'vanb', 'johnb', 'chuckr', 'tgr'],
            'composite_string': 'deonjohnbdarkotgrvanbchuckrfontlewin',
            'expected': 12451
        }
    ]
    
    for test_idx, test in enumerate(test_cases):
        dut._log.info(f"Running test {test_idx+1}: n={test['n']}, k={test['k']}")
        
        # Set n and k
        dut.n.value = test['n']
        dut.k.value = test['k']
        
        # Initialize initial_strings and initial_lengths
        for i in range(MAX_N):
            if i < test['n']:
                # Set the string
                s = test['initial_strings'][i]
                packed = pack_string(s)
                for j in range(MAX_STRING_LEN):
                    dut.initial_strings[i][j].value = packed[j]
                # Set the length
                dut.initial_lengths[i].value = len(s)
            else:
                # Clear unused entries
                for j in range(MAX_STRING_LEN):
                    dut.initial_strings[i][j].value = 0
                dut.initial_lengths[i].value = 0
        
        # Set composite string
        packed_composite = pack_composite_string(test['composite_string'])
        for i in range(MAX_COMPOSITE_LEN):
            dut.composite_string[i].value = packed_composite[i]
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {test_idx+1}: Result is undefined")
        
        result = int(dut.result.value)
        expected = test['expected']
        
        if result != expected:
            raise TestFailure(f"Test {test_idx+1}: Expected {expected}, got {result}")
        
        dut._log.info(f"Test {test_idx+1} PASSED: result = {result}")
        
        # Reset for next test
        await reset_dut(dut)
    
    dut._log.info("All tests passed!")