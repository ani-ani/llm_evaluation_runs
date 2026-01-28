import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
MAX_STRINGS = 8
STRING_WIDTH = 16
DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 500

# Helper functions (as per template)
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'clk'):
        for _ in range(cycles): await RisingEdge(dut.clk)
    else:
        await Timer(cycles * CLK_NS, units='ns')
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)

async def write_strings(dut, strings_list):
    # Initialize all to zero (null padding)
    for i in range(MAX_STRINGS):
        for j in range(STRING_WIDTH):
            dut.strings[i][j].value = 0
    
    # Write actual strings
    for i, s in enumerate(strings_list):
        for j, char in enumerate(s):
            if j >= STRING_WIDTH:
                break
            dut.strings[i][j].value = clamp_to_width(ord(char), DATA_WIDTH)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_longest_strings(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases based on Python docstring and check function
    test_cases = [
        ([], None, "Empty list"),
        (["a", "b", "c"], 0, "Single char tie (first)"),
        (["x", "yyy", "zzzz", "www", "kkkk", "abc"], 2, "Mixed lengths"),
        (["abcdef", "abc", "def"], 0, "First is longest"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp_strings, exp_idx, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - Input: {inp_strings}")
        try:
            # Set inputs
            if is_seq:
                await write_strings(dut, inp_strings)
                if has_signal(dut, 'num_strings'):
                    dut.num_strings.value = clamp_to_width(len(inp_strings), 4)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational logic fallback (not expected for this spec)
                await write_strings(dut, inp_strings)
                if has_signal(dut, 'num_strings'):
                    dut.num_strings.value = clamp_to_width(len(inp_strings), 4)
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.done.value) and is_seq:
                raise TestFailure("Done signal undefined")
            
            # Check valid flag if present
            if has_signal(dut, 'valid'):
                valid = int(dut.valid.value)
                if len(inp_strings) == 0 and valid != 0:
                    raise TestFailure(f"Expected valid=0 for empty list, got {valid}")
                if len(inp_strings) > 0 and valid != 1:
                    raise TestFailure(f"Expected valid=1 for non-empty list, got {valid}")
            
            # Check result
            if exp_idx is None:
                # For empty list, we just check valid flag logic above.
                # If valid flag doesn't exist, we check for specific 'null' value if defined,
                # but usually it's handled by valid bit.
                pass 
            else:
                if not is_value_defined(dut.longest_idx.value):
                    raise TestFailure("longest_idx undefined")
                result = int(dut.longest_idx.value)
                if result != exp_idx:
                    raise TestFailure(f"Expected index {exp_idx}, got {result}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Test {i+1}): {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")