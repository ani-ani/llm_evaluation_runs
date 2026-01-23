import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
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

async def write_array(dut, array_name, values, element_width):
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
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

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

def compute_max_cookies(times, durations, N):
    dp = [0] * (N + 1)
    for i in range(N-1, -1, -1):
        max_val = dp[i+1]
        for L in durations:
            j = i+1
            while j < N and times[j] < times[i] + L:
                j += 1
            val = L + dp[j]
            if val > max_val:
                max_val = val
        dp[i] = max_val
    return dp[0]

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_job_scheduler(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)

    durations = [2, 3, 4]
    test_cases = [
        ([0, 10, 20, 30], 4),
        ([0, 2, 3, 5], 4),
    ]

    passed = 0
    failed = 0

    for i, (times, N) in enumerate(test_cases):
        times_sorted = sorted(times)
        expected = compute_max_cookies(times_sorted, durations, N)
        cocotb.log.info(f"Test {i+1}: times={times_sorted}, N={N}, expected={expected}")

        try:
            padded_times = times_sorted + [0] * (8 - N)
            await write_array(dut, 'times', padded_times, DATA_WIDTH)
            if has_signal(dut, 'N'):
                dut.N.value = N
            else:
                raise TestFailure("Signal 'N' not found")
            await start_computation(dut)
            await wait_for_done(dut)
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1

    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")