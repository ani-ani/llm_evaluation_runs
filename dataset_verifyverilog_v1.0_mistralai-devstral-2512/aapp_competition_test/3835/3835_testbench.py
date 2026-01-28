import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

DATA_WIDTH = 32
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 200

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits - 1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_matrix_restore(dut):
    # Check if it's a sequential module
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')

    # Test cases: n, matrix (8x8), expected result
    test_cases = [
        (
            5,
            [
                [0, 4, 6, 2, 4, 0, 0, 0],
                [4, 0, 6, 2, 4, 0, 0, 0],
                [6, 6, 0, 3, 6, 0, 0, 0],
                [2, 2, 3, 0, 2, 0, 0, 0],
                [4, 4, 6, 2, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0]
            ],
            [2, 2, 3, 1, 2, 0, 0, 0]
        ),
        (
            3,
            [
                [0, 99990000, 99970002, 0, 0, 0, 0, 0],
                [99990000, 0, 99980000, 0, 0, 0, 0, 0],
                [99970002, 99980000, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0]
            ],
            [9999, 10000, 9998, 0, 0, 0, 0, 0]
        ),
        (
            8,
            [
                [0, 2, 3, 5, 7, 11, 13, 17],
                [2, 0, 6, 10, 14, 22, 26, 34],
                [3, 6, 0, 15, 21, 33, 39, 51],
                [5, 10, 15, 0, 35, 55, 65, 85],
                [7, 14, 21, 35, 0, 77, 91, 119],
                [11, 22, 33, 55, 77, 0, 143, 187],
                [13, 26, 39, 65, 91, 143, 0, 221],
                [17, 34, 51, 85, 119, 187, 221, 0]
            ],
            [1, 2, 3, 5, 7, 11, 13, 17]
        )
    ]

    passed = 0
    failed = 0

    for tc_idx, (n, matrix, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test case {tc_idx + 1}: n={n}")
        try:
            # Set n
            if has_signal(dut, 'n'):
                dut.n.value = n

            # Set matrix values individually
            # Flatten matrix for input assignment: matrix[row][col]
            # Assuming interface is dut.matrix_0_0, dut.matrix_0_1 ... or dut.matrix[0:63]
            for row in range(8):
                for col in range(8):
                    val = matrix[row][col]
                    # Try to find the signal
                    sig_name = f"matrix_{row}_{col}"
                    if has_signal(dut, sig_name):
                        getattr(dut, sig_name).value = clamp_to_width(val, DATA_WIDTH)
                    elif has_signal(dut, 'matrix'):
                        # Packed array access? Usually needs individual element access
                        # If it's a 1D array of 64 elements
                        idx = row * 8 + col
                        if idx < 64:
                            dut.matrix[idx].value = clamp_to_width(val, DATA_WIDTH)
                    else:
                        # Fallback for VHDL-style multi-dimensional ports if supported
                        try:
                            dut.matrix[row][col].value = clamp_to_width(val, DATA_WIDTH)
                        except Exception:
                            pass

            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')

            # Check results
            for i in range(n):
                res_sig = f"result_{i}"
                if has_signal(dut, res_sig):
                    result_val = int(getattr(dut, res_sig).value)
                elif has_signal(dut, 'result'):
                    # Assuming result is an array of 8 signals
                    result_val = int(dut.result[i].value)
                else:
                    raise TestFailure("Result signal not found")

                # Allow small tolerance if floating point was used, but spec asks for integer
                # In the problem, result is integer. We round if using fixed point.
                # The HDL should output integer.
                if result_val != expected[i]:
                    raise TestFailure(f"Index {i}: Expected {expected[i]}, got {result_val}")

            passed += 1
            cocotb.log.info(f"Test case {tc_idx + 1} passed")

        except TestFailure as e:
            cocotb.log.error(f"Test case {tc_idx + 1} failed: {e}")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed out of {passed + failed}")
