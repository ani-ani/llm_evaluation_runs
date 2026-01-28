import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_LEN = 16
CLK_NS = 10
MAX_CYCLES = 1000

def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, TypeError):
        return default

def clamp_to_width(v, bits):
    if v < 0:
        return 0
    max_val = (1 << bits) - 1
    return min(max_val, v)

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def python_common(l1, l2):
    """Python reference implementation"""
    set1 = set(l1)
    set2 = set(l2)
    common_set = set1 & set2
    result = sorted(list(common_set))
    return result

def pack_list(vals, width=8):
    """Pack list of values into a single integer for Verilog array"""
    r = 0
    for i, v in enumerate(vals):
        if i >= 16:
            break
        r |= ((v & ((1 << width) - 1)) << (i * width))
    return r

async def write_array(dut, name, vals, width):
    """Write values to Verilog array elements individually"""
    for i in range(16):
        if i < len(vals):
            val = clamp_to_width(vals[i], width)
        else:
            val = 0
        # Access array element by index
        if hasattr(dut, name) and hasattr(getattr(dut, name), '__getitem__'):
            getattr(dut, name)[i].value = val
        else:
            # Handle packed array access via individual signals
            signal_name = f"{name}_{i}"
            if has_signal(dut, signal_name):
                getattr(dut, signal_name).value = val

def pack_array(vals, bits=8):
    """Pack array values into single integer (for packed arrays)"""
    r = 0
    for i, v in enumerate(vals):
        if i >= 16:
            break
        v = clamp_to_width(v, bits)
        r |= (v & ((1 << bits) - 1)) << (i * bits)
    return r

async def reset_dut(dut, cycles=2):
    """Reset the DUT"""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    """Wait for done signal"""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_common(dut):
    """Test the common elements module"""
    
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (list1, list2, expected_result)
    test_cases = [
        ([1, 4, 3, 34, 653, 2, 5], [5, 7, 1, 5, 9, 653, 121], [1, 5, 653]),
        ([5, 3, 2, 8], [3, 2], [2, 3]),
        ([4, 3, 2, 8], [3, 2, 4], [2, 3, 4]),
        ([4, 3, 2, 8], [], []),
        ([1, 1, 1, 2], [1, 2, 2, 2], [1, 2]),
        ([], [1, 2, 3], []),
        ([], [], []),
    ]
    
    passed = 0
    failed = 0
    
    for i, (list1, list2, expected) in enumerate(test_cases):
        test_desc = f"Test {i+1}: {list1} & {list2} -> {expected}"
        cocotb.log.info(test_desc)
        
        try:
            # Write inputs
            await write_array(dut, 'list1', list1, DATA_WIDTH)
            await write_array(dut, 'list2', list2, DATA_WIDTH)
            
            # Set lengths
            if has_signal(dut, 'len1'):
                dut.len1.value = len(list1)
            if has_signal(dut, 'len2'):
                dut.len2.value = len(list2)
            
            # Start computation
            if is_seq:
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                await wait_for_done(dut, MAX_CYCLES)
            else:
                await Timer(1000, units='ns')
            
            # Read result
            if not is_value_defined(dut.result_len.value):
                raise TestFailure("result_len is undefined")
            
            result_len = int(dut.result_len.value)
            result_values = []
            
            # Read each result element
            for j in range(result_len):
                if has_signal(dut, 'result') and hasattr(getattr(dut, 'result'), '__getitem__'):
                    val = int(getattr(dut, 'result')[j].value)
                else:
                    signal_name = f"result_{j}"
                    if has_signal(dut, signal_name):
                        val = int(getattr(dut, signal_name).value)
                    else:
                        val = safe_int(0)
                result_values.append(val)
            
            # Sort expected (python_common already returns sorted)
            expected_sorted = expected
            
            # Compare
            if result_len != len(expected_sorted):
                raise TestFailure(
                    f"Length mismatch: expected {len(expected_sorted)}, got {result_len}. "
                    f"Expected {expected_sorted}, got {result_values}"
                )
            
            if result_values != expected_sorted:
                raise TestFailure(
                    f"Values mismatch: expected {expected_sorted}, got {result_values}"
                )
            
            passed += 1
            cocotb.log.info(f"  PASS: {result_values}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Small delay between tests for synchronization
        if is_seq and i < len(test_cases) - 1:
            await Timer(100, units='ns')
    
    if failed:
        raise TestFailure(f"{failed} of {passed+failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")