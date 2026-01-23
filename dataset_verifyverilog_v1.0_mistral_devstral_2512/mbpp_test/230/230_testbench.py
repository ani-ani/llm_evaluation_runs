import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
CHAR_WIDTH = 8
STRING_LEN = 16
CLK_PERIOD = 10

# Helper functions

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def write_str_array(dut, string_val, str_len):
    """Writes string to dut.str_in array elements."""
    # Truncate if necessary
    valid_chars = string_val[:STRING_LEN]
    
    # Write characters
    for i in range(STRING_LEN):
        if has_signal(dut, f'str_in_{i}'):
            attr = getattr(dut, f'str_in_{i}')
        else:
            attr = dut.str_in[i]
            
        if i < len(valid_chars):
            attr.value = ord(valid_chars[i])
        else:
            attr.value = 0

async def read_str_array(dut):
    """Reads dut.str_out array and returns string."""
    result = []
    for i in range(STRING_LEN):
        if has_signal(dut, f'str_out_{i}'):
            val = getattr(dut, f'str_out_{i}').value
        else:
            val = dut.str_out[i].value
            
        if is_value_defined(val):
            result.append(chr(int(val)))
        else:
            result.append('?')
    return ''.join(result)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_replace_blank(dut):
    # Clock and Reset
    clock = Clock(dut.clk, CLK_PERIOD, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Cases: (Input, Replacement, Expected)
    test_cases = [
        ("hello people", '@', "hello@people"),
        ("python program language", '$', "python$program$language"),
        ("blank space", '-', "blank-space"),
        ("no_spaces", 'X', "no_spaces      "),
    ]
    
    for test_idx, (in_str, rep_char, exp_str) in enumerate(test_cases):
        dut._log.info(f"Running Test {test_idx+1}: '{in_str}' -> '{exp_str}'")
        
        # Pad expected string to 16 chars for comparison
        exp_str_padded = exp_str.ljust(STRING_LEN, '\x00')
        str_len = min(len(in_str), STRING_LEN)
        
        # Setup Inputs
        await write_str_array(dut, in_str, str_len)
        dut.char_in.value = ord(rep_char)
        dut.str_len.value = str_len
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout)
        done = False
        for _ in range(100):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            raise TestFailure(f"Test {test_idx+1}: Timeout waiting for done")
        
        # Verify Output
        output = await read_str_array(dut)
        if output != exp_str_padded:
            raise TestFailure(f"Test {test_idx+1}: Exp '{exp_str_padded}' got '{output}'")
            
        dut._log.info(f"Test {test_idx+1}: PASS")
        await RisingEdge(dut.clk)
