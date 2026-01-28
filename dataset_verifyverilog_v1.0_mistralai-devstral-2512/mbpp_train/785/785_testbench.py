import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Constants
DATA_WIDTH = 8       # ASCII char width
ARRAY_SIZE = 4       # Max tuple elements
RESULT_WIDTH = 16    # Output integer width
CLK_NS = 10
MAX_CYCLES = 1000

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'char_valid'): dut.char_valid.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def feed_string(dut, test_str):
    """Feeds the string character by character into char_in and char_valid."""
    dut._log.info(f"Feeding string: '{test_str}'")
    for char in test_str:
        ascii_val = ord(char)
        dut.char_in.value = ascii_val
        dut.char_valid.value = 1
        await RisingEdge(dut.clk)
        # Wait for the DUT to potentially sample it. 
        # In a standard streaming interface, valid is high while data is valid.
        # Here we simulate a single cycle high valid pulse per char to be safe.
        dut.char_valid.value = 0
        await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout waiting for done after {max_cycles} cycles")

async def wait_for_result_valid(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
            return True
    raise TestFailure(f"Timeout waiting for result_valid after {max_cycles} cycles")

def get_result_array(dut):
    res = []
    for i in range(ARRAY_SIZE):
        if has_signal(dut, f'result_{i}'):
            val = getattr(dut, f'result_{i}').value
            res.append(int(val))
        elif has_signal(dut, 'result'):
            # Handle packed array if needed, but usually split is easier for testing
            # Assuming simple split ports for this testbench
            pass
    return res

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_tuple_parser(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: Input string -> Expected tuple of ints
    test_cases = [
        ("(7, 8, 9)", [7, 8, 9, 0]),
        ("(1, 2, 3)", [1, 2, 3, 0]),
        ("(4, 5, 6)", [4, 5, 6, 0]),
        ("(7, 81, 19)", [7, 81, 19, 0]),
    ]
    
    for i, (inp_str, expected) in enumerate(test_cases):
        dut._log.info(f"Running Test Case {i+1}: {inp_str}")
        
        # Wait for idle state (done=1)
        if not int(dut.done.value):
             await wait_for_done(dut)
             
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed the string data
        await feed_string(dut, inp_str)
        
        # Wait for result valid
        await wait_for_result_valid(dut)
        
        # Check results
        # Assuming the module has output ports result_0, result_1, etc.
        actual = []
        for idx in range(ARRAY_SIZE):
            port_name = f'result_{idx}'
            if has_signal(dut, port_name):
                val = int(getattr(dut, port_name).value)
                actual.append(val)
            else:
                raise TestFailure(f"Port {port_name} not found. Expected split output ports.")
        
        if actual != expected:
             raise TestFailure(f"Test {i+1} Failed: Expected {expected}, got {actual}")
             
    dut._log.info("All tests passed!")