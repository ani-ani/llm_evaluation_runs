import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 8
ARRAY_SIZE = 16
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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(CLK_NS, units='ns')
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut):
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    # Ensure we are in a clocked context for reset cycles
    if has_signal(dut, 'clk'):
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')
        if has_signal(dut, 'rst_n'):
            dut.rst_n.value = 1

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_exchange(dut):
    # Setup
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational design, just ensure inputs settle
        await Timer(10, units='ns')

    test_cases = [
        # (arr1, arr2, expected_result, description)
        ([1, 2, 3, 4], [1, 2, 3, 4], 1, "Simple YES"),
        ([1, 2, 3, 4], [1, 5, 3, 4], 0, "Simple NO"),
        ([1, 2, 3, 4], [2, 1, 4, 3], 1, "Swap YES"),
        ([5, 7, 3], [2, 6, 4], 1, "All odd in L1, All even in L2"),
        ([5, 7, 3], [2, 6, 3], 0, "Not enough evens in L2"),
        ([3, 2, 6, 1, 8, 9], [3, 5, 5, 1, 1, 1], 0, "Mixed NO"),
        ([100, 200], [200, 200], 1, "Large numbers YES"),
        ([1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 1, "Max size YES"),
        ([1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], 0, "Max size NO"),
    ]

    passed = 0
    failed = 0

    for i, (arr1_vals, arr2_vals, exp, desc) in enumerate(test_cases):
        # Pad inputs to ARRAY_SIZE
        arr1_full = arr1_vals + [0] * (ARRAY_SIZE - len(arr1_vals))
        arr2_full = arr2_vals + [0] * (ARRAY_SIZE - len(arr2_vals))
        length = len(arr1_vals)

        cocotb.log.info(f"Test {i+1}/{len(test_cases)}: {desc} (Len={length})")

        try:
            # Write Inputs
            if has_signal(dut, 'arr1'):
                for k in range(ARRAY_SIZE):
                    dut.arr1[k].value = clamp_to_width(arr1_full[k], DATA_WIDTH)
            elif has_signal(dut, 'arr1_0'):
                for k in range(ARRAY_SIZE):
                    getattr(dut, f'arr1_{k}').value = clamp_to_width(arr1_full[k], DATA_WIDTH)
            
            if has_signal(dut, 'arr2'):
                for k in range(ARRAY_SIZE):
                    dut.arr2[k].value = clamp_to_width(arr2_full[k], DATA_WIDTH)
            elif has_signal(dut, 'arr2_0'):
                for k in range(ARRAY_SIZE):
                    getattr(dut, f'arr2_{k}').value = clamp_to_width(arr2_full[k], DATA_WIDTH)
            
            if has_signal(dut, 'len'):
                dut.len.value = clamp_to_width(length, 4)

            # Trigger
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational logic needs time to settle
                await Timer(10, units='ns')

            # Check Output
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal is undefined (X or Z)")
            
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1

        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
