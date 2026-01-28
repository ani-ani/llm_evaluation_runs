import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

MAX_N = 16
DATA_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_cluster_min(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (6, [0,10,12,5,11,11], [10,0,8,5,2,3], [0,1,1,0,1,0], 4),
        (10, [6,0,2,6,8,4,4,2,6,6], [1,2,1,1,2,4,0,3,1,3], [1,0,1,1,0,0,0,1,0,1], 8),
        (3, [5,5,5], [7,7,7], [1,1,1], 3),
        (2, [0,1], [0,0], [1,0], 1),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, a_list, b_list, c_list, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}")
        for j in range(MAX_N):
            if j < n:
                dut.a[j].value = a_list[j]
                dut.b[j].value = b_list[j]
                dut.c[j].value = c_list[j]
            else:
                dut.a[j].value = 0
                dut.b[j].value = 0
                dut.c[j].value = 0
        dut.n.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"Test {i+1}: result undefined")
            failed += 1
            continue
        result = int(dut.result.value)
        if result == expected:
            cocotb.log.info(f"Test {i+1} PASS")
            passed += 1
        else:
            cocotb.log.error(f"Test {i+1} FAIL: expected {expected}, got {result}")
            failed += 1
    
    cocotb.log.info(f"Results: {passed}/{passed+failed} passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")