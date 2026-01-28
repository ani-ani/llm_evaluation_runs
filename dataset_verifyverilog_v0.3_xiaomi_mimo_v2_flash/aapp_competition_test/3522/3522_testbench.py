import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================
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

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_battery_allocator(dut):
    MAX_BATTERIES = 16
    BATTERY_WIDTH = 8
    CLK_PERIOD = 10  # ns

    # Detect module type
    is_sequential = has_signal(dut, 'clk')
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD, units='ns').start())
        await reset_dut(dut)

    # Test cases: (n, k, battery_list, expected_result, description)
    test_cases = [
        (2, 3, [1,2,3,4,5,6,7,8,9,10,11,12], 1, "Sample 1"),
        (2, 2, [3,1,3,3,3,3,3,3], 2, "Sample 2"),
    ]

    for n, k, batteries, expected, desc in test_cases:
        cocotb.log.info(f"Running test: {desc}")

        # Set n and k
        dut.n.value = n
        dut.k.value = k

        # Fill battery array: first len(batteries) values, rest 255
        for i in range(MAX_BATTERIES):
            if i < len(batteries):
                val = batteries[i]
            else:
                val = 255
            val = clamp_to_width(val, BATTERY_WIDTH)
            # Assign to array (try indexed access)
            try:
                dut.batteries[i].value = val
            except (AttributeError, TypeError):
                raise TestFailure(f"Cannot access batteries[{i}]")

        # Start computation
        if is_sequential:
            await start_computation(dut)
            await wait_for_done(dut)
        else:
            await Timer(100, units='ns')

        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result is undefined (X/Z)")
        result = int(dut.result.value)

        if result != expected:
            raise TestFailure(f"Test {desc}: expected {expected}, got {result}")

        cocotb.log.info(f"  PASS: result = {result}")

    cocotb.log.info("All tests passed")