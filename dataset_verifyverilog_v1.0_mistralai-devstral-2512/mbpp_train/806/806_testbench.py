import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
STRING_LEN = 16
CLK_NS = 10
MAX_CYCLES = 100

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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_string(dut, test_str):
    padded = (test_str + '\x00' * (STRING_LEN - len(test_str)))[:STRING_LEN]
    for i, char in enumerate(padded):
        if hasattr(dut, f'char_{i}'):
            getattr(dut, f'char_{i}').value = ord(char)
        elif hasattr(dut, 'char'):
            dut.char[i].value = ord(char)
        else:
            raise TestFailure(f"Port pattern for char_{i} not found")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_run_uppercase(dut):
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')

    test_cases = [
        ('GeMKSForGERksISBESt', 5, "Mixed case, max run 5"),
        ('PrECIOusMOVemENTSYT', 6, "Mixed case, max run 6"),
        ('GooGLEFluTTER', 4, "Mixed case, max run 4"),
        ('', 0, "Empty string"),
        ('ABCDEFGHIJKLMNO', 15, "Max run 15 (padded)"),
        ('1234567890', 0, "No uppercase")
    ]

    passed = failed = 0

    for inp_str, exp, desc in test_cases:
        cocotb.log.info(f"Test: {desc}")
        try:
            await write_string(dut, inp_str)

            if has_signal(dut, 'clk'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, max_cycles=20)
            else:
                await Timer(10, units='ns')

            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal is undefined")

            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")

            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed")