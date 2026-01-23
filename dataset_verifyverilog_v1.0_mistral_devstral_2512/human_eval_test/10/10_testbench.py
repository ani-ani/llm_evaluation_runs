import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

async def feed_string(dut, input_str):
    """Feeds the string to the DUT character by character."""
    dut.valid_in.value = 1
    for char in input_str:
        dut.char_in.value = ord(char)
        await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    # Pulse finish_in
    dut.finish_in.value = 1
    await RisingEdge(dut.clk)
    dut.finish_in.value = 0

async def get_output_string(dut):
    """Reads the output stream from the DUT."""
    result = []
    timeout = 50 # cycles to wait for valid output
    count = 0
    while count < timeout:
        await RisingEdge(dut.clk)
        if is_value_defined(dut.valid_out.value) and dut.valid_out.value == 1:
            if not is_value_defined(dut.char_out.value):
                raise TestFailure("char_out undefined while valid_out high")
            result.append(chr(int(dut.char_out.value)))
        
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
        count += 1
    else:
        raise TestFailure("Timeout waiting for done signal")
    return "".join(result)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_make_palindrome(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.finish_in.value = 0
    dut.char_in.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases
    test_cases = [
        ("", ""),
        ("x", "x"),
        ("xyx", "xyx"),
        ("xyz", "xyzyx"),
        ("cat", "catac"),
        ("jerry", "jerryrrej")
    ]

    for input_str, expected in test_cases:
        dut._log.info(f"Testing: '{input_str}' -> '{expected}'")
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed input
        await feed_string(dut, input_str)
        
        # Get output
        result = await get_output_string(dut)
        
        if result != expected:
            raise TestFailure(f"Expected '{expected}', got '{result}'")
        
        await RisingEdge(dut.clk)
