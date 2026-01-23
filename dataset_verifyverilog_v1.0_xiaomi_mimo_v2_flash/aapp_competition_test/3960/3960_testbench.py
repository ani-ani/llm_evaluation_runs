import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Config
DATA_WIDTH = 64
ARRAY_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Helper functions
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

# Array access helpers
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

async def read_array(dut, array_name, size):
    results = []
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                results.append(int(arr[i].value))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    return results

# Combinational wait
async def wait_for_combinational(dut, timeout_ns=10000):
    elapsed = 0
    while elapsed < timeout_ns:
        await Timer(10, units='ns')
        elapsed += 10
        if is_value_defined(dut.max_value.value):
            return
    raise TestFailure("Combinational output not valid after timeout")

# Expected value computation
def compute_max_f(arr):
    n = len(arr)
    if n < 2:
        return 0
    diffs = [abs(arr[i] - arr[i+1]) for i in range(n-1)]
    b1 = []
    b2 = []
    for i in range(n-1):
        if i % 2 == 0:
            b1.append(diffs[i])
        else:
            b1.append(-diffs[i])
        b2.append(-b1[-1])
    max_ending_here = b1[0]
    max_so_far = b1[0]
    for i in range(1, len(b1)):
        max_ending_here = max(b1[i], max_ending_here + b1[i])
        max_so_far = max(max_so_far, max_ending_here)
    max_b1 = max_so_far
    max_ending_here = b2[0]
    max_so_far = b2[0]
    for i in range(1, len(b2)):
        max_ending_here = max(b2[i], max_ending_here + b2[i])
        max_so_far = max(max_so_far, max_ending_here)
    max_b2 = max_so_far
    return max(max_b1, max_b2)

# Main test
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_f(dut):
    is_sequential = has_signal(dut, 'clk')
    is_combinational = not is_sequential

    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        pass

    test_cases = [
        ([1,4,2,3,1,0,0,0], compute_max_f([1,4,2,3,1,0,0,0])),
        ([1,5,4,7,0,0,0,0], compute_max_f([1,5,4,7,0,0,0,0])),
        ([0,0,0,0,0,0,0,0], 0),
        ([10,20,30,40,50,60,70,80], compute_max_f([10,20,30,40,50,60,70,80])),
        ([-5,-9,0,44,-10,37,34,-49], compute_max_f([-5,-9,0,44,-10,37,34,-49])),
        ([1000000000,0,0,1000000000,1000000000,0,0,1000000000], compute_max_f([1000000000,0,0,1000000000,1000000000,0,0,1000000000])),
    ]

    passed = 0
    failed = 0

    for idx, (arr, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: arr={arr}, expected={expected}")
        await write_array(dut, 'a', arr, DATA_WIDTH)
        if is_sequential:
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                for cycle in range(MAX_CYCLES):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                else:
                    raise TestFailure(f"Timeout waiting for done")
            else:
                await Timer(100, units='ns')
        else:
            await wait_for_combinational(dut)
        if not is_value_defined(dut.max_value.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        result = int(dut.max_value.value)
        result_signed = to_signed(result, DATA_WIDTH)
        if result_signed != expected:
            raise TestFailure(f"Test {idx+1}: expected {expected}, got {result_signed}")
        cocotb.log.info(f"  PASS: result = {result_signed}")
        passed += 1

    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")