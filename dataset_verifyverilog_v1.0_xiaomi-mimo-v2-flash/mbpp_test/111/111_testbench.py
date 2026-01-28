import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
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
    if has_signal(dut, 'list_valid'): dut.list_valid.value = 0
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

async def write_sublist(dut, sublist, sublist_idx):
    """Write a sublist via data stream"""
    dut.sublist_idx.value = sublist_idx
    dut.sublist_len.value = len(sublist)
    await RisingEdge(dut.clk)
    for i, val in enumerate(sublist):
        dut.sublist_data.value = clamp_to_width(val, 8)
        dut.list_valid.value = 1
        await RisingEdge(dut.clk)
    dut.list_valid.value = 0

async def read_result(dut):
    """Read common elements array"""
    common = []
    if has_signal(dut, 'common'):
        # Array of signals
        for i in range(16):
            elem_sig = getattr(dut, f'common[{i}]')
            if is_value_defined(elem_sig.value):
                val = int(elem_sig.value)
                if val != 0 or i < safe_int(dut.common_count.value, 0):
                    common.append(val)
    return common

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_common_in_nested_lists(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)

    # Test cases: each is list of sublists, expected intersection
    test_cases = [
        ([[12, 18, 23, 25, 45], [7, 12, 18, 24, 28], [1, 5, 8, 12, 15, 16, 18]], {12, 18}),
        ([[12, 5, 23, 25, 45], [7, 11, 5, 23, 28], [1, 5, 8, 18, 23, 16]], {5, 23}),
        ([[2, 3, 4, 1], [4, 5], [6, 4, 8], [4, 5], [6, 8, 4]], {4}),
    ]

    for test_idx, (nested, expected_set) in enumerate(test_cases):
        cocotb.log.info(f"Test case {test_idx+1}")
        if len(nested) > 8:
            cocotb.log.warning(f"Skipping test {test_idx+1}: too many sublists ({len(nested)})")
            continue

        # Write sublists
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        for idx, sublist in enumerate(nested):
            if len(sublist) > 16:
                cocotb.log.warning(f"Skipping sublist {idx}: too many elements ({len(sublist)})")
                continue
            await write_sublist(dut, sublist, idx)

        # Wait for processing
        if not await wait_for_done(dut, 500):
            raise TestFailure("Processing did not complete")

        # Check result
        await RisingEdge(dut.clk)  # Result available when done=1
        common = await read_result(dut)
        common_set = set(common)

        if common_set != expected_set:
            raise TestFailure(f"Test {test_idx+1}: Expected {expected_set}, got {common_set}")

        cocotb.log.info(f"Test {test_idx+1} passed")
        await RisingEdge(dut.clk)
