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

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure("Timeout waiting for done")

async def set_ratio(dut, index, numerator, denominator):
    n_port = getattr(dut, f'n{index}')
    d_port = getattr(dut, f'd{index}')
    n_port.value = clamp_to_width(numerator, 8)
    d_port.value = clamp_to_width(denominator, 8)

async def set_ratios(dut, ratios):
    for i, (num, den) in enumerate(ratios):
        await set_ratio(dut, i, num, den)

async def read_output(dut):
    front1 = int(dut.front1.value)
    front2 = int(dut.front2.value)
    rears = [int(dut.rear1.value), int(dut.rear2.value), int(dut.rear3.value),
             int(dut.rear4.value), int(dut.rear5.value), int(dut.rear6.value)]
    valid = int(dut.valid.value)
    return front1, front2, rears, valid

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_valid_distinct_fronts(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test case: front 19,20; rear 17,15,14,13,7,2
    ratios = [
        (19,17), (19,15), (19,14), (19,13), (19,7), (19,2),
        (20,17), (20,15), (20,14), (20,13), (20,7), (20,2)
    ]
    await set_ratios(dut, ratios)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)
    
    front1, front2, rears, valid = await read_output(dut)
    
    if not valid:
        raise TestFailure("Valid signal should be high")
    
    front_set = {front1, front2}
    if front_set != {19, 20}:
        raise TestFailure(f"Expected fronts 19 and 20, got {front1}, {front2}")
    
    expected_rears = {17, 15, 14, 13, 7, 2}
    rear_set = set(rears)
    if rear_set != expected_rears:
        raise TestFailure(f"Expected rears {expected_rears}, got {rear_set}")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_valid_same_fronts(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Front 10, rear 2,3,4,5,6,7 with duplicates
    ratios = [
        (10,2), (10,2), (10,3), (10,3), (10,4), (10,4),
        (10,5), (10,5), (10,6), (10,6), (10,7), (10,7)
    ]
    await set_ratios(dut, ratios)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)
    
    front1, front2, rears, valid = await read_output(dut)
    
    if not valid:
        raise TestFailure("Valid signal should be high")
    
    if front1 != 10 or front2 != 10:
        raise TestFailure(f"Expected fronts both 10, got {front1}, {front2}")
    
    expected_rears = {2,3,4,5,6,7}
    rear_set = set(rears)
    if rear_set != expected_rears:
        raise TestFailure(f"Expected rears {expected_rears}, got {rear_set}")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_invalid_three_numerators(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Three distinct numerators
    ratios = [
        (10,2), (11,2), (12,2),
        (10,3), (11,3), (12,3),
        (10,4), (11,4), (12,4),
        (10,5), (11,5), (12,5)
    ]
    await set_ratios(dut, ratios)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)
    
    front1, front2, rears, valid = await read_output(dut)
    
    if valid:
        raise TestFailure("Valid signal should be low for this test case")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_invalid_seven_denominators(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Seven distinct denominators
    ratios = [
        (10,2), (10,3), (10,4), (10,5), (10,6), (10,7), (10,8),
        (20,2), (20,3), (20,4), (20,5), (20,6)
    ]
    await set_ratios(dut, ratios)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)
    
    front1, front2, rears, valid = await read_output(dut)
    
    if valid:
        raise TestFailure("Valid signal should be low for this test case")