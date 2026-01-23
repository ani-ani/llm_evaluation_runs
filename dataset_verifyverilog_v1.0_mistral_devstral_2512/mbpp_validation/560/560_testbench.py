import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
ARRAY_SIZE = 4
OUTPUT_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 200

# Helper functions from template
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

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def write_input_arrays(dut, arr_a, arr_b):
    """Write two 4-element input arrays."""
    # Write arr_a
    if has_signal(dut, 'arr_a_0'):
        dut.arr_a_0.value = clamp_to_width(arr_a[0], DATA_WIDTH)
        dut.arr_a_1.value = clamp_to_width(arr_a[1], DATA_WIDTH)
        dut.arr_a_2.value = clamp_to_width(arr_a[2], DATA_WIDTH)
        dut.arr_a_3.value = clamp_to_width(arr_a[3], DATA_WIDTH)
    else:
        raise TestFailure("Signal arr_a_0 not found")
    
    # Write arr_b
    if has_signal(dut, 'arr_b_0'):
        dut.arr_b_0.value = clamp_to_width(arr_b[0], DATA_WIDTH)
        dut.arr_b_1.value = clamp_to_width(arr_b[1], DATA_WIDTH)
        dut.arr_b_2.value = clamp_to_width(arr_b[2], DATA_WIDTH)
        dut.arr_b_3.value = clamp_to_width(arr_b[3], DATA_WIDTH)
    else:
        raise TestFailure("Signal arr_b_0 not found")

async def read_output_array(dut):
    """Read output array."""
    results = []
    for i in range(OUTPUT_SIZE):
        port_name = f'result_{i}'
        if has_signal(dut, port_name):
            sig = getattr(dut, port_name)
            if is_value_defined(sig.value):
                results.append(int(sig.value))
            else:
                results.append(None)
        else:
            results.append(None)
    return results

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_union_arrays(dut):
    """Test union of two 4-element arrays with sorting and duplicate removal."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (arr_a, arr_b, expected_union)
    # Each array has 4 elements, union is sorted with no duplicates
    test_cases = [
        (
            [3, 4, 5, 6],
            [5, 7, 4, 10],
            [3, 4, 5, 6, 7, 10]
        ),
        (
            [1, 2, 3, 4],
            [3, 4, 5, 6],
            [1, 2, 3, 4, 5, 6]
        ),
        (
            [11, 12, 13, 14],
            [13, 15, 16, 17],
            [11, 12, 13, 14, 15, 16, 17]
        )
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_a, arr_b, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: arr_a={arr_a}, arr_b={arr_b}")
        
        try:
            # Write inputs
            await write_input_arrays(dut, arr_a, arr_b)
            
            # Pulse start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            result = await read_output_array(dut)
            
            # Filter out None and padding (255)
            valid_results = [r for r in result if r is not None and r != 255]
            
            # Verify
            if valid_results != expected:
                raise TestFailure(f"Expected {expected}, got {valid_results}")
            
            cocotb.log.info(f"  PASS: {valid_results}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")