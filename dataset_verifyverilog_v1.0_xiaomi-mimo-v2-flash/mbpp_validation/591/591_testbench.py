import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 16
LEN_WIDTH = 4
CLK_NS = 10
MAX_CYCLES = 1000

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
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_array_elements(dut, vals, width):
    """Write array elements individually to match Verilog constraints"""
    for i in range(ARRAY_SIZE):
        if i < len(vals):
            val = clamp_to_width(vals[i], width)
        else:
            val = 0
        if has_signal(dut, f'arr_{i}'):
            getattr(dut, f'arr_{i}').value = val
        else:
            # Try indexed array access
            dut.arr[i].value = val

async def read_result_array(dut):
    """Read result array elements individually"""
    result = []
    for i in range(ARRAY_SIZE):
        if has_signal(dut, f'result_{i}'):
            val = int(getattr(dut, f'result_{i}').value)
        else:
            val = int(dut.result[i].value)
        result.append(val)
    return result

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_swap_list(dut):
    """Test swap function with various test cases"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational version
        await Timer(100, units='ns')
    
    test_cases = [
        ([12, 35, 9, 56, 24], [24, 35, 9, 56, 12], 5, "Two elements swap"),
        ([1, 2, 3], [3, 2, 1], 3, "Three elements swap"),
        ([4, 5, 6], [6, 5, 4], 3, "Simple three"),
        ([5], [5], 1, "Single element (no swap)"),
        ([], [], 0, "Empty array (no swap)"),
        ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16], 
         [16, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 1], 16, "Full 16 elements")
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_arr, expected_arr, length, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write input array
            await write_array_elements(dut, input_arr, DATA_WIDTH)
            
            # Write length if it exists
            if has_signal(dut, 'len') and length > 0:
                dut.len.value = length
            elif has_signal(dut, 'len'):
                dut.len.value = 0
            
            if is_seq:
                # Start operation
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                    
                    # Wait for done
                    await wait_for_done(dut)
                else:
                    await Timer(100, units='ns')
            else:
                # Combinational - just wait
                await Timer(100, units='ns')
            
            # Read result
            result = await read_result_array(dut)
            
            # Check only the first 'length' elements
            if length > 0:
                actual_first = result[0]
                actual_last = result[length-1]
                exp_first = expected_arr[0]
                exp_last = expected_arr[length-1]
                
                if actual_first != exp_first:
                    raise TestFailure(f"First element mismatch: expected {exp_first}, got {actual_first}")
                if actual_last != exp_last:
                    raise TestFailure(f"Last element mismatch: expected {exp_last}, got {actual_last}")
                
                # Check middle elements are unchanged
                for j in range(1, length-1):
                    if result[j] != input_arr[j]:
                        raise TestFailure(f"Middle element {j} changed: expected {input_arr[j]}, got {result[j]}")
            
            passed += 1
            cocotb.log.info(f"  PASS: {desc}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed out of {passed + failed}")