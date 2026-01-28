import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def write_t_array(dut, t_list, n):
    for i in range(8):
        if i < n:
            dut.t_i[i].value = clamp_to_width(t_list[i], 8)
        else:
            dut.t_i[i].value = 0

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_dog_show(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (3, 5, [1,5,3], 2),
        (1, 2, [1], 1),
        (1, 1, [1], 0),
        (1, 1, [2], 0),
        (2, 2, [2,3], 0),
        (2, 3, [2,3], 1),
        (2, 3, [2,1], 1),
        (3, 3, [2,3,2], 1),
        (3, 4, [2,1,2], 2),
        (4, 4, [2,3,2,3], 2),
    ]
    
    for i, (n, T, t_list, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, T={T}, t={t_list}, expected={expected}")
        dut.n.value = n
        dut.T.value = T
        await write_t_array(dut, t_list, n)
        
        await start_computation(dut)
        await wait_for_done(dut)
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Test {i+1} failed: expected {expected}, got {result}")
        else:
            cocotb.log.info(f"Test {i+1} passed")
    
    cocotb.log.info("All tests passed!")