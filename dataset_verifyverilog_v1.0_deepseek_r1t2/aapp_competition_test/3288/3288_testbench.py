import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# CONFIGURATION
DATA_WIDTH = 8
MAX_K = 4
MAX_LEN = 10
N_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

# HELPER FUNCTIONS
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
    return min(max_val, max(0, value))

# DUT INTERFACE HELPERS
async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut, k, n):
    k_clamped = clamp_to_width(k, 6)
    n_clamped = clamp_to_width(n, N_WIDTH)
    dut.k.value = k_clamped
    dut.n.value = n_clamped
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f'Timeout: done not asserted after {max_cycles} cycles')

async def read_result(dut, max_len=MAX_LEN):
    result = []
    for i in range(max_len):
        port_name = f'char_{i}'
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val) and int(val) != 0:
                result.append(chr(int(val)))
            else:
                break
        else:
            break
    return ''.join(result)

async def read_error(dut):
    if has_signal(dut, 'error'):
        if is_value_defined(dut.error.value):
            return int(dut.error.value) == 1
    return False

# TEST CASES
TEST_CASES = [
    (2, 1, 'aba', 'k=2, n=1'),
    (2, 650, 'zyz', 'k=2, n=650 (last valid)'),
    (2, 651, None, 'k=2, n=651 (exceeds count)'),
    (3, 1, 'ababac', 'k=3, n=1'),
    (3, 2, 'ababad', 'k=3, n=2'),
    (3, 3, 'ababae', 'k=3, n=3'),
    (3, 26, 'ababaz', 'k=3, n=26'),
    (3, 27, 'ababca', 'k=3, n=27'),
    (1, 1, 'a', 'k=1, n=1'),
    (1, 2, None, 'k=1, n=2 (exceeds count)'),
]

# MAIN TEST
@cocotb.test(timeout_time=10000, timeout_unit='ms')
async def test_incremental_double_free_generator(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    await Timer(100, units='ns')
    passed = 0
    failed = 0
    for k, n, expected, description in TEST_CASES:
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f'Test: {description}')
        cocotb.log.info(f'k={k}, n={n}, expected={expected}')
        try:
            await start_computation(dut, k, n)
            await wait_for_done(dut, max_cycles=5000)
            error_occurred = await read_error(dut)
            if expected is None:
                if not error_occurred:
                    raise TestFailure(f'Expected error for n={n}, but got none')
                cocotb.log.info('  PASS: Correctly reported error')
                passed += 1
            else:
                if error_occurred:
                    raise TestFailure(f'Unexpected error for n={n}')
                result = await read_result(dut)
                if result != expected:
                    raise TestFailure(f'Expected {expected!r}, got {result!r}')
                cocotb.log.info(f'  PASS: Got {result!r}')
                passed += 1
        except TestFailure as e:
            cocotb.log.error(f'  FAIL: {e}')
            failed += 1
        except Exception as e:
            cocotb.log.error(f'  ERROR: Unexpected exception: {e}')
            failed += 1
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f'RESULTS: {passed}/{passed+failed} tests passed')
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')