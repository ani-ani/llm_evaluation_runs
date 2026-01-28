import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 200

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
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def set_inputs(dut, arr_vals, length):
    # Ensure array size matches module ports (arr_0 to arr_7)
    for i in range(ARRAY_SIZE):
        val = arr_vals[i] if i < len(arr_vals) else 0
        sig_name = f'arr_{i}'
        if has_signal(dut, sig_name):
            getattr(dut, sig_name).value = clamp_to_width(val, DATA_WIDTH)
    dut.len.value = clamp_to_width(length, 4)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_unique_product(dut):
    # Setup clock if present
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic - just set inputs
        dut.rst_n.value = 1

    # Test cases adapted for 8-bit and max 8 elements
    # Python unlimited ints scaled: 720000000 fits in 32-bit
    test_cases = [
        ([10, 20, 30, 40, 20, 50, 60, 40], 8, 720000000),
        ([1, 2, 3, 1, 0, 0, 0, 0], 4, 6),
        ([7, 8, 9, 0, 1, 1, 0, 0], 6, 0)
    ]

    passed = failed = 0

    for i, (inp, length, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Input={inp}, Length={length}")
        try:
            await set_inputs(dut, inp, length)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X or Z)")
            
            result = int(dut.result.value)
            # Truncate Python result to 32-bit for comparison (saturation not expected, but logic handles)
            expected_32 = expected & 0xFFFFFFFF
            
            if result != expected_32:
                raise TestFailure(f"Expected {expected_32}, got {result}")
            passed += 1
            cocotb.log.info(f"  PASS: Result {result}")
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    cocotb.log.info(f"All {passed} tests passed.")