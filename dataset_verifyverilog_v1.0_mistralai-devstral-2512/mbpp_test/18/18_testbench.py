import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, int(v)))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done signal not asserted after {max_cycles} cycles")

# Helper to set strings
def set_string(dut, string, len_val, prefix):
    # Clamp length to max 8
    actual_len = min(len(string), 8)
    for i in range(8):
        port_name = f"{prefix}_{i}"
        if has_signal(dut, port_name):
            if i < actual_len:
                val = ord(string[i])
                getattr(dut, port_name).value = clamp_to_width(val, 8)
            else:
                getattr(dut, port_name).value = 0
    if has_signal(dut, len_val):
        getattr(dut, len_val).value = actual_len

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_remove_dirty_chars(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(10, units='ns')

    # Test cases
    test_cases = [
        ("probasscurve", "pros", "bacuve"),
        ("digitalindia", "talent", "digiidi"),
        ("exoticmiles", "toxic", "emles"),
        ("aaa", "a", ""),
        ("hello", "xyz", "hello")
    ]

    for str1, str2, expected in test_cases:
        # Set inputs
        set_string(dut, str1, 'len1', 'str1')
        set_string(dut, str2, 'len2', 'str2')
        
        # Start
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        else:
            await RisingEdge(dut.clk)

        # Wait for done
        await wait_for_done(dut)

        # Read result
        if has_signal(dut, 'result_len'):
            res_len = int(dut.result_len.value)
        else:
            res_len = 0
        
        res_str = ""
        for i in range(8):
            port_name = f"result_{i}"
            if has_signal(dut, port_name):
                val = int(getattr(dut, port_name).value)
                if i < res_len:
                    res_str += chr(val)
        
        if res_str != expected:
            raise TestFailure(f"Input: '{str1}', Filter: '{str2}' | Expected '{expected}', got '{res_str}'")
        
        # Reset for next test
        if has_signal(dut, 'clk'):
            await reset_dut(dut)
