import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
MAX_ELEMENTS = 16
CLK_NS = 10
TIMEOUT_CYCLES = 1000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, width):
    return v & ((1 << width) - 1)

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=TIMEOUT_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, name, vals, width):
    # Helper to write individual elements to array ports
    for i, v in enumerate(vals):
        # Check if the specific element port exists
        attr_name = f"{name}_{i}"
        if has_signal(dut, attr_name):
            getattr(dut, attr_name).value = clamp_to_width(v, width)
        elif hasattr(dut, name) and hasattr(dut.name, '__getitem__'):
            # Handle case where dut.name is an array-like object
            try:
                dut.name[i].value = clamp_to_width(v, width)
                continue
            except:
                pass
        # Fallback: construct signal name with brackets (common in some simulators)
        else:
            try:
                # This is a heuristic as accessing generated arrays varies by simulator
                # We'll try to access by index if it's a modifiable array
                pass 
            except:
                pass
    
    # Aggressive fallback: Iterate if standard access failed
    # We assume dut.arr is a list of signals or dut.arr_0 exists
    # Let's assume dut.arr_0 ... dut.arr_15 convention
    pass # Logic is inside the loop above

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_remove_elements(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Define Test Cases (list1, list2, expected_result)
    test_cases = [
        ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], [2, 4, 6, 8], [1, 3, 5, 7, 9, 10]),
        ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], [1, 3, 5, 7], [2, 4, 6, 8, 9, 10]),
        ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], [5, 7], [1, 2, 3, 4, 6, 8, 9, 10]),
        ([10, 20, 30, 40], [10, 40], [20, 30]),
        ([5, 5, 5], [5], []),
        ([], [1, 2, 3], []),
        ([1, 2, 3], [], [1, 2, 3])
    ]

    passed = 0
    failed = 0

    for i, (list1, list2, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}: Remove {list2} from {list1}")
        
        try:
            # Write Input Arrays
            # We use a helper function that handles the specific signal naming convention
            # Assuming dut.arr1_0, dut.arr1_1... and dut.arr2_0, dut.arr2_1...
            for idx in range(MAX_ELEMENTS):
                val1 = list1[idx] if idx < len(list1) else 0
                val2 = list2[idx] if idx < len(list2) else 0
                getattr(dut, f'arr1_{idx}').value = clamp_to_width(val1, DATA_WIDTH)
                getattr(dut, f'arr2_{idx}').value = clamp_to_width(val2, DATA_WIDTH)
            
            # Write Lengths
            dut.len1.value = len(list1)
            dut.len2.value = len(list2)
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for Done
            await wait_for_done(dut)
            
            # Read Result
            # Length first
            len_out = int(dut.len_out.value)
            
            # Read Result Array
            result = []
            for idx in range(MAX_ELEMENTS):
                if idx < len_out:
                    val = int(getattr(dut, f'result_{idx}').value)
                    result.append(val)
            
            # Validate
            if result != expected:
                cocotb.log.error(f"Test {i+1} Failed: Expected {expected}, got {result}")
                failed += 1
            else:
                cocotb.log.info(f"Test {i+1} Passed")
                passed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} Exception: {e}")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
