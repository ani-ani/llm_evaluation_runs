import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_morse(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([1,1,1], [1,3,7]),
        ([1,0,1,0,1], [1,4,10,22,43]),
        ([1,1,0,0,0,1,1,0,1], [1,3,10,24,51,109,213,421,833]),
        ([1], [1]),
        ([0], [1]),
        ([0,0,0], [1,3,7]),
        ([1,0,0,1,0,0,0,0,1,1,1,1,1,0,0], [1,4,10,24,51,103,215,431,855,1626,3168,5912,10969,20336,39070]),
        ([1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0], [1,3,10,24,53,105,209,409,794,1483,2861,5513,10617,19751,38019,73177,140841,261931,504111,970203]),
        ([1,0,1,0,1,1,0,1,1,0,1,0,1,1,0,0,1,0,0,0,1,1,1,1,1,0,1,0,0,1], [1,4,10,22,43,99,207,415,815,1587,3075,6043,11350,21964,42393,81925,158005,304829,587813,1133252,2184596,4064376,7823948,14514657,26844724,49625092,95185828,182547725,350580848,674317028]),
        ([1,1,0,1,0,0,0,0,0,1,1,0,1,1,1,0,0,1,1,0,1,1,1,1,0,1,0,0,1,1,1,0,1,0,1,1,1,1,0,1,0,0,0,0,1,0,1,0,0,1], [1,3,10,24,51,109,221,437,853,1682,3168,6140,11860,22892,44135,82151,158191,304543,564961,1085797,2089447,4020703,7736863,14388308,26687491,51285871,98551264,189365676,364343151,677400510,303515263,417664883,645964151,927585198,551655236,799795319,181925830,436266469,320877702,90100168,380405024,578884218,721503333,122130227,154161765,927919646,134336201,547169339,972208491,790255221]),
        ([1,0], [1,4]),
        ([1,1,1], [1,3,7]),
        ([1,1,1,1], [1,3,7,14]),
        ([1,1,1,1,1], [1,3,7,14,27]),
        ([0,0], [1,3]),
        ([0,0,0,0], [1,3,7,15]),
        ([0,0,0,0,0], [1,3,7,15,30]),
        ([1,1], [1,3]),
        ([1,1,1], [1,3,7]),
        ([1,1,1,1], [1,3,7,14]),
        ([1,1,1,1,1], [1,3,7,14,27]),
    ]
    
    for idx, (bits, expected) in enumerate(test_cases):
        dut._log.info(f"Test case {idx+1}: input bits = {bits}")
        await reset_dut(dut)
        for i, bit in enumerate(bits):
            dut.bit_in.value = bit
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await Timer(1, units='ns')
            if not is_value_defined(dut.done.value) or int(dut.done.value) != 1:
                raise TestFailure(f"Done not asserted after bit {i}")
            ans = int(dut.answer.value)
            expected_ans = expected[i]
            if ans != expected_ans:
                raise TestFailure(f"Test {idx+1} bit {i}: expected {expected_ans}, got {ans}")
            dut._log.info(f"  After bit {i+1}, answer = {ans} (expected {expected_ans})")
        dut._log.info(f"Test case {idx+1} passed")