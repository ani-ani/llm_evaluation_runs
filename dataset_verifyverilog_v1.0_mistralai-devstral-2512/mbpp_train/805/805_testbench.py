import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 8
MAX_LISTS = 16
MAX_ELEMS = 16
CLK_NS = 10
MAX_CYCLES = 256

def is_value_defined(v):
    try: int(v); return True
    except (ValueError, TypeError): return False

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

async def write_lists(dut, lists_data, lengths_data, num_lists):
    """Write 2D array data to flattened port structure"""
    # Write to flattened array: lists[i][j]
    for i in range(len(lists_data)):
        list_len = lengths_data[i]
        for j in range(MAX_ELEMS):
            if j < list_len:
                val = lists_data[i][j]
            else:
                val = 0
            # Access as flattened array: lists[i*MAX_ELEMS + j]
            idx = i * MAX_ELEMS + j
            dut.lists[idx].value = clamp_to_width(val, DATA_WIDTH)
    
    # Write lengths array
    for i in range(MAX_LISTS):
        if i < len(lengths_data):
            dut.lengths[i].value = clamp_to_width(lengths_data[i], 4)
        else:
            dut.lengths[i].value = 0
    
    # Write num_lists
    dut.num_lists.value = clamp_to_width(num_lists, 4)

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_max_sum_list(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        {
            'desc': 'Multiple lists with clear max',
            'lists': [[1,2,3], [4,5,6], [10,11,12], [7,8,9]],
            'lengths': [3,3,3,3],
            'num_lists': 4,
            'exp_list': [10,11,12],
            'exp_index': 2,
            'exp_sum': 33
        },
        {
            'desc': 'Sorted descending sums',
            'lists': [[3,2,1], [6,5,4], [12,11,10]],
            'lengths': [3,3,3],
            'num_lists': 3,
            'exp_list': [12,11,10],
            'exp_index': 2,
            'exp_sum': 33
        },
        {
            'desc': 'Single list',
            'lists': [[2,3,1]],
            'lengths': [3],
            'num_lists': 1,
            'exp_list': [2,3,1],
            'exp_index': 0,
            'exp_sum': 6
        }
    ]
    
    passed = failed = 0
    
    for test in test_cases:
        cocotb.log.info(f"Test: {test['desc']}")
        
        try:
            # Write input data
            await write_lists(dut, test['lists'], test['lengths'], test['num_lists'])
            
            # Start operation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut, MAX_CYCLES)
            
            # Read results
            if not is_value_defined(dut.result_index.value):
                raise TestFailure("result_index undefined")
            result_index = int(dut.result_index.value)
            
            if not is_value_defined(dut.max_sum.value):
                raise TestFailure("max_sum undefined")
            max_sum = int(dut.max_sum.value)
            
            # Read selected list (16 elements)
            result_list = []
            for i in range(MAX_ELEMS):
                signal_name = f'result_list_{i}'
                if has_signal(dut, signal_name):
                    val = int(getattr(dut, signal_name).value)
                    result_list.append(val)
                else:
                    # Try as array access
                    try:
                        val = int(dut.result_list[i].value)
                        result_list.append(val)
                    except:
                        # For packed result, we need to extract
                        if i < len(test['exp_list']):
                            # Try to extract from packed value
                            pass
            
            # Verify index
            if result_index != test['exp_index']:
                raise TestFailure(f"Index mismatch: expected {test['exp_index']}, got {result_index}")
            
            # Verify sum
            if max_sum != test['exp_sum']:
                raise TestFailure(f"Sum mismatch: expected {test['exp_sum']}, got {max_sum}")
            
            # Verify list content (check first few elements)
            for i, expected_val in enumerate(test['exp_list']):
                if i >= MAX_ELEMS:
                    break
                if result_list[i] != expected_val:
                    raise TestFailure(f"List element {i} mismatch: expected {expected_val}, got {result_list[i]}")
            
            cocotb.log.info(f"PASS: Index={result_index}, Sum={max_sum}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            
    if failed:
        raise TestFailure(f"{failed} test(s) failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed")