import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 8
NAME_WIDTH = 4
NUM_TUPLES = 8
CLK_NS = 10
MAX_CYCLES = 250

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_input(dut, names, marks, valid):
    """Write input arrays element by element"""
    for i in range(NUM_TUPLES):
        dut.in_name[i].value = clamp_to_width(names[i], NAME_WIDTH)
        dut.in_marks[i].value = clamp_to_width(marks[i], DATA_WIDTH)
        dut.in_valid[i].value = valid[i]

async def read_output(dut):
    """Read output arrays element by element"""
    names = []
    marks = []
    valids = []
    for i in range(NUM_TUPLES):
        if has_signal(dut, f'out_name_{i}'):
            n = safe_int(getattr(dut, f'out_name_{i}').value)
            m = safe_int(getattr(dut, f'out_marks_{i}').value)
            v = safe_int(getattr(dut, f'out_valid_{i}').value)
        else:
            n = safe_int(dut.out_name[i].value)
            m = safe_int(dut.out_marks[i].value)
            v = safe_int(dut.out_valid[i].value)
        names.append(n)
        marks.append(m)
        valids.append(v)
    return names, marks, valids

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_subject_marks_sort(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational design
        await Timer(100, units='ns')

    # Test cases: (input_names, input_marks, input_valid, expected_names, expected_marks, description)
    test_cases = [
        # Test 1: 4 tuples
        ([0, 1, 2, 3, 0, 0, 0, 0], [88, 90, 97, 82, 0, 0, 0, 0], [1, 1, 1, 1, 0, 0, 0, 0],
         [3, 0, 1, 2, 0, 0, 0, 0], [82, 88, 90, 97, 0, 0, 0, 0], "4 tuples: English, Science, Maths, Social"),
        
        # Test 2: 3 tuples
        ([4, 5, 6, 0, 0, 0, 0, 0], [49, 54, 33, 0, 0, 0, 0, 0], [1, 1, 1, 0, 0, 0, 0, 0],
         [6, 4, 5, 0, 0, 0, 0, 0], [33, 49, 54, 0, 0, 0, 0, 0], "3 tuples: Telugu, Hindhi, Social"),
        
        # Test 3: 3 tuples (different)
        ([7, 8, 9, 0, 0, 0, 0, 0], [96, 97, 45, 0, 0, 0, 0, 0], [1, 1, 1, 0, 0, 0, 0, 0],
         [9, 7, 8, 0, 0, 0, 0, 0], [45, 96, 97, 0, 0, 0, 0, 0], "3 tuples: Physics, Chemistry, Biology"),
        
        # Test 4: 8 tuples (stress test)
        ([0,1,2,3,4,5,6,7], [10,9,8,7,6,5,4,3], [1]*8,
         [7,6,5,4,3,2,1,0], [3,4,5,6,7,8,9,10], "8 tuples: reverse order"),
        
        # Test 5: All same marks (stable? not required, just sorted)
        ([1,2,3,4,0,0,0,0], [50,50,50,50,0,0,0,0], [1,1,1,1,0,0,0,0],
         [1,2,3,4,0,0,0,0], [50,50,50,50,0,0,0,0], "All same marks"),
    ]

    passed = 0
    failed = 0

    for test_idx, (in_names, in_marks, in_valid, exp_names, exp_marks, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx+1}: {desc}")
        
        try:
            # Write inputs
            await write_input(dut, in_names, in_marks, in_valid)
            
            if has_signal(dut, 'clk'):
                # Sequential: trigger start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational: just wait
                await Timer(100, units='ns')
            
            # Read outputs
            out_names, out_marks, out_valids = await read_output(dut)
            
            # Check validity first
            valid_count = sum(out_valids)
            expected_valid_count = sum(in_valid)
            if valid_count != expected_valid_count:
                raise TestFailure(f"Valid count mismatch: expected {expected_valid_count}, got {valid_count}")
            
            # Check only valid entries
            valid_indices = [i for i, v in enumerate(out_valids) if v == 1]
            expected_indices = [i for i, v in enumerate(exp_valid) if v == 1]
            
            # Verify marks are sorted ascending
            for i in range(len(valid_indices) - 1):
                if out_marks[valid_indices[i]] > out_marks[valid_indices[i+1]]:
                    raise TestFailure(f"Marks not sorted: {out_marks[valid_indices[i]]} > {out_marks[valid_indices[i+1]]}")
            
            # Verify marks and names match expected (after sorting)
            for i in valid_indices:
                if out_marks[i] != exp_marks[i]:
                    raise TestFailure(f"Mismatch at {i}: expected mark {exp_marks[i]}, got {out_marks[i]}")
                if out_names[i] != exp_names[i]:
                    raise TestFailure(f"Mismatch at {i}: expected name {exp_names[i]}, got {out_names[i]}")
            
            cocotb.log.info(f"  PASS: {valid_count} tuples sorted")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")