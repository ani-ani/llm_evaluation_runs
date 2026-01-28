import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_NAMES = 16
MAX_NAME_LEN = 16
CLK_NS = 10
MODULO = 1000000007

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def send_name(dut, name_str):
    # Send characters one by one, but since interface is 24-bit (3 chars), we can batch.
    # For simplicity, we assume one char per cycle on name_in[7:0] and valid_in high.
    # However, spec says name_in is 24-bit (3 chars). Let's adapt: send 3 chars per cycle.
    # If name_len is not multiple of 3, pad with 0s.
    chars = [ord(c) for c in name_str]
    padded = chars + [0] * (MAX_NAME_LEN - len(chars))
    for i in range(0, len(padded), 3):
        chunk = padded[i:i+3]
        val = 0
        for j, c in enumerate(chunk):
            val |= (c << (j * DATA_WIDTH))
        dut.name_in.value = clamp_to_width(val, 24)
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
        dut.valid_in.value = 0
        # Wait for ready if needed
        if has_signal(dut, 'ready'):
            while int(dut.ready.value) == 0:
                await RisingEdge(dut.clk)

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_name_ordering(dut):
    # Check if sequential
    if not has_signal(dut, 'clk'):
        cocotb.log.info("Combinational design, skipping sequential test")
        return

    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test case 1: 3 names
    names1 = ["IVO", "JASNA", "JOSIPA"]
    expected1 = 4

    # Feed names
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for name in names1:
        # Wait for ready
        if has_signal(dut, 'ready'):
            while int(dut.ready.value) == 0:
                await RisingEdge(dut.clk)
        await send_name(dut, name)

    # Signal end
    dut.done_in.value = 1
    await RisingEdge(dut.clk)
    dut.done_in.value = 0

    # Wait for done
    await wait_for_done(dut)

    # Read result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result undefined after computation")
    result = int(dut.result.value)
    if result != expected1:
        raise TestFailure(f"Test 1 Failed: Expected {expected1}, got {result}")
    cocotb.log.info(f"Test 1 Passed: Result {result}")

    # Reset for next test
    await reset_dut(dut)

    # Test case 2: 5 names
    names2 = ["MARICA", "MARTA", "MATO", "MARA", "MARTINA"]
    expected2 = 24

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    for name in names2:
        if has_signal(dut, 'ready'):
            while int(dut.ready.value) == 0:
                await RisingEdge(dut.clk)
        await send_name(dut, name)

    dut.done_in.value = 1
    await RisingEdge(dut.clk)
    dut.done_in.value = 0

    await wait_for_done(dut)

    result = int(dut.result.value)
    if result != expected2:
        raise TestFailure(f"Test 2 Failed: Expected {expected2}, got {result}")
    cocotb.log.info(f"Test 2 Passed: Result {result}")

    # Test case 3: 4 names
    names3 = ["A", "AA", "AAA", "AAAA"]
    expected3 = 8

    await reset_dut(dut)

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    for name in names3:
        if has_signal(dut, 'ready'):
            while int(dut.ready.value) == 0:
                await RisingEdge(dut.clk)
        await send_name(dut, name)

    dut.done_in.value = 1
    await RisingEdge(dut.clk)
    dut.done_in.value = 0

    await wait_for_done(dut)

    result = int(dut.result.value)
    if result != expected3:
        raise TestFailure(f"Test 3 Failed: Expected {expected3}, got {result}")
    cocotb.log.info(f"Test 3 Passed: Result {result}")