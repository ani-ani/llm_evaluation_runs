import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants for scaled problem (D=8, M=16, N=8)
MAX_EVENTS = 8
MAX_IMPL = 16
DATA_WIDTH = 4  # Events 1-8 fit in 4 bits
CLK_NS = 10

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

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
    if has_signal(dut, 'load_impl'):
        dut.load_impl.value = 0
        dut.load_known.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=500):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_sherlock(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic fallback (unlikely for this complexity)
        await Timer(100, units='ns')

    # Helper to load data
    async def load_implication(a, b, idx):
        dut.implications_a.value = clamp_to_width(a, DATA_WIDTH)
        dut.implications_b.value = clamp_to_width(b, DATA_WIDTH)
        dut.impl_idx.value = clamp_to_width(idx, 4) # 0-15
        dut.load_impl.value = 1
        await RisingEdge(dut.clk)
        dut.load_impl.value = 0

    async def load_known(val, idx):
        dut.known_val.value = clamp_to_width(val, DATA_WIDTH)
        dut.known_idx.value = clamp_to_width(idx, 3) # 0-7
        dut.load_known.value = 1
        await RisingEdge(dut.clk)
        dut.load_known.value = 0

    # Test Case 1: 3 2 1
    # Implications: 1->2, 2->3
    # Known: 2
    # Expected: 1 2 3
    cocotb.log.info("Loading Test Case 1")
    await load_implication(1, 2, 0)
    await load_implication(2, 3, 1)
    await load_known(2, 0)

    # Start calculation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)

    result = int(dut.result.value)
    # Events 1, 2, 3 -> bits 0, 1, 2
    expected = (1 << 0) | (1 << 1) | (1 << 2)
    if result != expected:
        raise TestFailure(f"Test 1 Failed: Expected {expected:08b}, got {result:08b}")
    cocotb.log.info(f"Test 1 Passed: Result {result:08b}")

    # Reset for next test
    await reset_dut(dut)

    # Test Case 2: 3 2 1
    # Implications: 1->3, 2->3
    # Known: 3
    # Expected: 3 (1 and 2 are not certain)
    cocotb.log.info("Loading Test Case 2")
    await load_implication(1, 3, 0)
    await load_implication(2, 3, 1)
    await load_known(3, 0)

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)

    result = int(dut.result.value)
    # Event 3 -> bit 2
    expected = (1 << 2)
    if result != expected:
        raise TestFailure(f"Test 2 Failed: Expected {expected:08b}, got {result:08b}")
    cocotb.log.info(f"Test 2 Passed: Result {result:08b}")

    # Reset for next test
    await reset_dut(dut)

    # Test Case 3: 4 4 1
    # Implications: 1->2, 1->3, 2->4, 3->4
    # Known: 4
    # Expected: 1 2 3 4
    cocotb.log.info("Loading Test Case 3")
    await load_implication(1, 2, 0)
    await load_implication(1, 3, 1)
    await load_implication(2, 4, 2)
    await load_implication(3, 4, 3)
    await load_known(4, 0)

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)

    result = int(dut.result.value)
    # Events 1, 2, 3, 4 -> bits 0, 1, 2, 3
    expected = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3)
    if result != expected:
        raise TestFailure(f"Test 3 Failed: Expected {expected:08b}, got {result:08b}")
    cocotb.log.info(f"Test 3 Passed: Result {result:08b}")
