import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'clk'):
        for _ in range(cycles): await RisingEdge(dut.clk)
    else:
        await Timer(10, units='ns')
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_rookie_bunny(dut):
    DATA_WIDTH = 4
    CLK_NS = 10
    
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    async def wait_for_done(max_cycles=10000):
        if not is_seq: return
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                return
        raise TestFailure(f"Timeout after {max_cycles} cycles")

    test_vectors = [
        {"n": 5, "s1": 15, "s2": 15, "t": [7, 11, 9, 12, 2], "exp": 4},
        {"n": 5, "s1": 15, "s2": 15, "t": [16, 1, 1, 1, 1], "exp": 4},
        {"n": 3, "s1": 10, "s2": 10, "t": [5, 6, 5], "exp": 3},
    ]

    for test in test_vectors:
        n, s1, s2 = test["n"], test["s1"], test["s2"]
        times = [clamp_to_width(t, DATA_WIDTH) for t in test["t"]]
        expected = test["exp"]
        
        cocotb.log.info(f"Running test: n={n}, s1={s1}, s2={s2}, t={times}, exp={expected}")
        
        if is_seq:
            dut.start.value = 1
            dut.n.value = n
            dut.s1.value = s1
            dut.s2.value = s2
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            if has_signal(dut, 'load_ready'):
                for t_val in times:
                    loaded = False
                    for _ in range(20):
                        if is_value_defined(dut.load_ready.value) and int(dut.load_ready.value) == 1:
                            dut.t_i.value = t_val
                            loaded = True
                            break
                        await RisingEdge(dut.clk)
                    if not loaded:
                        raise TestFailure("load_ready never asserted")
                    await RisingEdge(dut.clk)
            else:
                dut.t_i.value = times[0]
                await RisingEdge(dut.clk)
            
            await wait_for_done()
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            await reset_dut(dut)
        else:
            await Timer(100, units='ns')