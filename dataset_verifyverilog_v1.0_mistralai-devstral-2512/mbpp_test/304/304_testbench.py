import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_find_element(dut):
    # Setup clock if synchronous
    if has_signal(dut, 'clk'):
        clock = Clock(dut.clk, 10, units='ns')
        cocotb.start_soon(clock.start())
        dut.rst_n.value = 0
        dut.start.value = 0
        if has_signal(dut, 'done'):
            dut.done.value = 0
        if has_signal(dut, 'result'):
            dut.result.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational logic handling
        dut.rst_n.value = 1
        dut.start.value = 0
        await Timer(10, units='ns')

    # Python reference implementation
    def reference_find_element(arr, ranges, rotations, index):
        # rotations here matches num_ranges
        for i in range(rotations - 1, -1, -1):
            left = ranges[i][0]
            right = ranges[i][1]
            if left <= index and right >= index:
                if index == left:
                    index = right
                else:
                    index = index - 1
        return arr[index]

    # Test cases
    test_cases = [
        ([1,2,3,4,5], [[0,2],[0,3]], 2, 1, 3),
        ([1,2,3,4], [[0,1],[0,2]], 1, 2, 3),
        ([1,2,3,4,5,6], [[0,1],[0,2]], 1, 1, 1)
    ]

    passed = 0
    failed = 0

    for t_idx, (arr, ranges, rotations, target_idx, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {t_idx + 1}: arr={arr}, ranges={ranges}, rot={rotations}, idx={target_idx}")
        
        # Clamp values to HDL constraints (8-bit data, 4-bit index/range)
        n_arr = [clamp_to_width(x, 8) for x in arr]
        n_ranges = [(clamp_to_width(l, 4), clamp_to_width(r, 4)) for l, r in ranges]
        n_target = clamp_to_width(target_idx, 4)
        n_rot = clamp_to_width(rotations, 2)
        n_num_ranges = clamp_to_width(len(ranges), 2)

        # Write inputs
        for i in range(16):
            val = n_arr[i] if i < len(n_arr) else 0
            dut.arr[i].value = val
        
        for i in range(4):
            if i < len(n_ranges):
                dut.range_left[i].value = n_ranges[i][0]
                dut.range_right[i].value = n_ranges[i][1]
            else:
                dut.range_left[i].value = 0
                dut.range_right[i].value = 0

        dut.rotations.value = n_rot
        dut.num_ranges.value = n_num_ranges
        dut.target_index.value = n_target

        # Trigger
        dut.start.value = 1
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            if has_signal(dut, 'done'):
                max_cycles = 100
                for _ in range(max_cycles):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                else:
                    cocotb.log.error(f"Test {t_idx + 1} Timeout")
                    failed += 1
                    continue
            else:
                # If no done signal, assume combinational or just wait
                await Timer(50, units='ns')
        else:
            # Combinational
            await Timer(10, units='ns')

        # Read result
        if has_signal(dut, 'result'):
            if is_value_defined(dut.result.value):
                res = int(dut.result.value)
                if res == expected:
                    cocotb.log.info(f"PASS: Result {res}")
                    passed += 1
                else:
                    cocotb.log.error(f"FAIL: Expected {expected}, got {res}")
                    failed += 1
            else:
                cocotb.log.error(f"FAIL: Result undefined")
                failed += 1
        else:
            cocotb.log.error("FAIL: 'result' signal missing")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed")
