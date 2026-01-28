import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
MAX_N = 100
DATA_WIDTH = 16
ADDR_WIDTH = 7
CLK_NS = 10

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n_in.value = 0
    for _ in range(3): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Python Reference
def get_max_sum(n):
    if n < 0: return 0
    res = [0] * (n + 1)
    if n >= 1: res[1] = 1
    for i in range(2, n + 1):
        s = 0
        if i//2 <= n: s += res[i//2]
        if i//3 <= n: s += res[i//3]
        if i//4 <= n: s += res[i//4]
        if i//5 <= n: s += res[i//5]
        res[i] = max(i, s)
    return res[n]

@cocotb.test(timeout_time=20, timeout_unit="s")
async def test_max_sum(dut):
    # Start clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational test logic if applicable (though this is sequential)
        await Timer(100, units='ns')

    test_values = [2, 10, 25, 60, 100]
    
    for n in test_values:
        dut._log.info(f"Testing n={n}")
        
        # Set inputs
        dut.n_in.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result signal undefined for n={n}")
            
        hdl_result = int(dut.result.value)
        py_result = get_max_sum(n)
        
        dut._log.info(f"n={n}: Expected={py_result}, Got={hdl_result}")
        
        if hdl_result != py_result:
            raise TestFailure(f"Mismatch for n={n}: Expected {py_result}, Got {hdl_result}")
            
        await RisingEdge(dut.clk)

    dut._log.info("All tests passed!")