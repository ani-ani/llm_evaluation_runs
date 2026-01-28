import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 8
STRING_LEN = 16
CLK_NS = 10
MAX_CYCLES = 300

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

def str_to_packed(s):
    packed = 0
    # Pad to 16 chars
    chars = s.ljust(STRING_LEN, ' ')
    for i in range(STRING_LEN):
        val = ord(chars[i])
        packed |= (val & 0xFF) << (i * 8)
    return packed

def packed_to_str(packed_val):
    s = ""
    for i in range(STRING_LEN):
        char_val = (packed_val >> (i * 8)) & 0xFF
        s += chr(char_val)
    return s

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_anti_shuffle(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic only
        await Timer(10, units='ns')

    # Test cases from problem
    test_cases = [
        ('Hi', 'Hi'),
        ('hello', 'ehllo'),
        ('number', 'bemnru'),
        ('abcd', 'abcd'),
        ('Hello World!!!', 'Hello !!!Wdlor'),
        ('', ''),
        ('Hi. My name is Mister Robot. How are you?', '.Hi My aemn is Meirst .Rboot How aer ?ouy')
    ]

    for (inp_str, exp_str) in test_cases:
        cocotb.log.info(f"Testing input: '{inp_str}'")
        
        # Prepare input
        in_packed = str_to_packed(inp_str)
        if has_signal(dut, 'in_str'):
            dut.in_str.value = in_packed
        elif has_signal(dut, 'in_str_0'):
            # Handle unpacked input array if spec differs, though prompt says packed
            pass
            
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done or timeout
            done_seen = False
            for _ in range(MAX_CYCLES):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done_seen = True
                    break
            
            if not done_seen:
                raise TestFailure(f"Timeout waiting for done on input '{inp_str}'")
        else:
            # Combinational, wait for propagation
            await Timer(100, units='ns')

        # Read output
        if not is_value_defined(dut.out_str.value):
             raise TestFailure(f"Output undefined for '{inp_str}'")
        
        out_packed = int(dut.out_str.value)
        out_str = packed_to_str(out_packed)
        
        # Compare (strip padding for comparison if desired, or compare full padded)
        # Problem implies exact string match, padded input should result in padded output?
        # The Python test cases are strict. We compare the exact 16 chars generated.
        # However, Python results are shorter than 16. 
        # We need to align the expected string to our output width.
        # Our output is fixed 16 chars. Input "Hi" is padded to "Hi              ".
        # Sorting "Hi              " -> "Hi              " (spaces don't sort with letters usually, but here spaces are delimiters)
        # The python logic: "Hi" -> "Hi". 
        # Our logic: Input "Hi" padded to 16 chars.
        # Word "Hi" -> sorted "Hi". 
        # Result should be "Hi" followed by spaces.
        
        expected_padded = exp_str.ljust(STRING_LEN, ' ')
        
        if out_str != expected_padded:
             raise TestFailure(f"Input: '{inp_str}'\nExpected: '{expected_padded}'\nGot:      '{out_str}'")

    raise TestFailure("All tests passed!") # Just to end cleanly or log success if wrapper needs it
