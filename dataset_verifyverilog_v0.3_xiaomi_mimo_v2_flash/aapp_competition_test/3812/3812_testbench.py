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

def pack_string(s):
    result = 0
    for i, c in enumerate(s[:16]):
        if c == 'b':
            result |= (1 << i)
    return result

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_module(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    test_cases = [
        ("bab", "bb", 2),
        ("bbbb", "aaa", 0),
        ("a", "b", 0),
        ("ab", "ba", 1),
    ]
    
    for s, t, expected in test_cases:
        dut.s_data.value = pack_string(s)
        dut.t_data.value = pack_string(t)
        dut.s_len.value = len(s)
        dut.t_len.value = len(t)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 100:
                raise TestFailure("Timeout")
        
        op_count = int(dut.op_count.value)
        if op_count != expected:
            raise TestFailure(f"Expected {expected}, got {op_count}")