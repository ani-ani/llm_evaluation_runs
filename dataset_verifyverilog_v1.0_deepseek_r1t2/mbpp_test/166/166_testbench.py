import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_find_even_pair(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([5, 4, 7, 2, 1], 4),
        ([7, 2, 8, 1, 0, 5, 11], 9),
        ([1, 2, 3], 1),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_list, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {input_list} -> expected {expected}")
        
        # Write inputs
        for j in range(8):
            port_name = f"arr_{j}"
            if has_signal(dut, port_name):
                if j < len(input_list):
                    getattr(dut, port_name).value = clamp_to_width(input_list[j], DATA_WIDTH)
                else:
                    getattr(dut, port_name).value = 0
        
        dut.len.value = len(input_list)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut)
        
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"  FAIL: Result undefined")
            failed += 1
            continue
        
        result = int(dut.result.value)
        if result == expected:
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
        else:
            cocotb.log.error(f"  FAIL: expected {expected}, got {result}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
