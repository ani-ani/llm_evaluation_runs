import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Helper Functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

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

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_garbage_disposal(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (3, 2, [3, 2, 1, 0, 0, 0, 0, 0], 3, "Example 1"),
        (3, 2, [1, 0, 1, 0, 0, 0, 0, 0], 2, "Example 2"),
        (4, 4, [2, 8, 4, 1, 0, 0, 0, 0], 4, "Example 3"),
        (1, 1, [0, 0, 0, 0, 0, 0, 0, 0], 0, "All zeros"),
        (1, 1, [1, 0, 0, 0, 0, 0, 0, 0], 1, "Single unit"),
        (2, 3, [2, 7, 0, 0, 0, 0, 0, 0], 3, "Carryover"),
        (8, 255, [255]*8, 8, "Max values"),
    ]
    
    passed = 0
    failed = 0
    
    for n, k, a_list, expected, desc in test_cases:
        cocotb.log.info(f"Test: {desc}")
        dut.n.value = n
        dut.k.value = k
        for i in range(8):
            setattr(dut, f'a_{i}', a_list[i])
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        cycles = 0
        while not safe_int(dut.done.value, 0) and cycles < MAX_CYCLES:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= MAX_CYCLES:
            cocotb.log.error(f"  TIMEOUT")
            failed += 1
            continue
        
        if not is_value_defined(dut.bags.value):
            cocotb.log.error("  Result undefined")
            failed += 1
            continue
        
        result = int(dut.bags.value)
        if result == expected:
            cocotb.log.info(f"  PASS: {result}")
            passed += 1
        else:
            cocotb.log.error(f"  FAIL: expected {expected}, got {result}")
            failed += 1
    
    cocotb.log.info(f"Results: {passed}/{passed+failed} passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")