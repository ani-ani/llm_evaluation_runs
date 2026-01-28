import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_max_executables(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)

    # Test cases: (N, arr, expected)
    test_cases = [
        (4, [1,2,1,2], 3),
        (6, [6,4,2,2,2,2], 3),
    ]

    for N, arr, expected in test_cases:
        dut._log.info(f'Test case: N={N}, arr={arr}, expected={expected}')
        dut.N.value = N

        # Set array values
        for i in range(8):
            if i < N:
                getattr(dut, f'arr_{i}').value = arr[i]
            else:
                getattr(dut, f'arr_{i}').value = 0

        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        done = False
        for _ in range(1000):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break

        if not done:
            raise TestFailure(f'Timeout waiting for done')

        # Read result
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f'Expected {expected}, got {result}')

        dut._log.info(f'PASS')

    dut._log.info('All tests passed')