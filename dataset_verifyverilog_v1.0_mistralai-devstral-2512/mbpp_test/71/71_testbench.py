import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
MAX_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 2000

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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'load_done'):
        dut.load_done.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def load_array(dut, arr, width):
    # Simulate loading via addr_in and data_in
    # In design, load_done goes high after all loads
    for i, val in enumerate(arr):
        dut.addr_in.value = i
        dut.data_in.value = clamp_to_width(val, width)
        await RisingEdge(dut.clk)
    # Pulse load_done after last element
    dut.load_done.value = 1
    await RisingEdge(dut.clk)
    dut.load_done.value = 0

def comb_sort_python(nums):
    shrink_fact = 1.3
    gaps = len(nums)
    swapped = True
    while gaps > 1 or swapped:
        gaps = int(float(gaps) / shrink_fact)
        swapped = False
        i = 0
        while gaps + i < len(nums):
            if nums[i] > nums[i+gaps]:
                nums[i], nums[i+gaps] = nums[i+gaps], nums[i]
                swapped = True
            i += 1
    return nums

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_comb_sort(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        raise TestFailure("Sequential design expected")

    test_cases = [
        ([5, 15, 37, 25, 79], [5, 15, 25, 37, 79]),
        ([41, 32, 15, 19, 22], [15, 19, 22, 32, 41]),
        ([99, 15, 13, 47], [13, 15, 47, 99])
    ]

    passed = failed = 0
    for idx, (inp, exp) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: input {inp}, expected {exp}")
        try:
            # Load array
            await load_array(dut, inp, DATA_WIDTH)
            # Set array size (load done also sets it)
            dut.array_size.value = len(inp)
            await RisingEdge(dut.clk)
            
            # Start sorting
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0

            # Wait for done
            cycles = 0
            while cycles < MAX_CYCLES:
                await RisingEdge(dut.clk)
                cycles += 1
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
            else:
                raise TestFailure(f"Timeout waiting for done after {cycles} cycles")

            # Read sorted output via valid/index/result stream
            sorted_result = []
            cycles_out = 0
            while cycles_out < MAX_CYCLES:
                await RisingEdge(dut.clk)
                cycles_out += 1
                if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
                    result_val = int(dut.result.value)
                    idx_val = int(dut.index.value)
                    sorted_result.append(result_val)
                    cocotb.log.info(f"  Output: idx={idx_val}, val={result_val}")
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1 and cycles_out > cycles:
                    # After sorting done, output stream should finish
                    # In this design, done may be asserted after output
                    if len(sorted_result) >= len(inp):
                        break
            
            if len(sorted_result) != len(exp):
                raise TestFailure(f"Output length mismatch: got {len(sorted_result)}, expected {len(exp)}")
            
            # Verify sorted order
            if sorted_result != exp:
                raise TestFailure(f"Expected {exp}, got {sorted_result}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed out of {failed+passed}")
