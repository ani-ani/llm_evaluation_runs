import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def write_array_fixed(dut, name, values, width):
    """Write array to fixed ports arr_0, arr_1..."""
    for i in range(ARRAY_SIZE):
        port_name = f"{name}_{i}"
        if has_signal(dut, port_name):
            val = values[i] if i < len(values) else 0
            getattr(dut, port_name).value = clamp_to_width(val, width)

def write_array_packed(dut, name, values, width):
    """Write packed array (single port)"""
    port = getattr(dut, name)
    packed = 0
    for i, v in enumerate(values):
        packed |= (clamp_to_width(v, width) << (i * width))
    port.value = packed

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_left_insertion(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    test_cases = [
        # (array, x, expected_result, description)
        ([1, 2, 4, 5], 6, 4, "Insert at end (all < x)"),
        ([1, 2, 4, 5], 3, 2, "Insert between elements"),
        ([1, 2, 4, 5], 7, 4, "Insert at end (all < x, larger)"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 1, 0, "Insert at beginning"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 8, 7, "Insert at existing position 8"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 9, 8, "Insert after all (len=8)"),
        ([10, 20, 30, 40], 25, 2, "Insert between large numbers"),
        ([5, 5, 5, 5], 5, 0, "All elements equal"),
        ([], 5, 0, "Empty array"),
        ([100], 50, 0, "Single element, insert before"),
        ([50], 100, 1, "Single element, insert after"),
        ([1, 2, 3, 4, 5, 6, 7, 8], 2, 1, "Middle value"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr, x, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        cocotb.log.info(f"  Input: arr={arr}, x={x}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Write array
            if is_seq:
                # Check for arr_0 style ports
                if has_signal(dut, 'arr_0'):
                    write_array_fixed(dut, 'arr', arr, DATA_WIDTH)
                elif has_signal(dut, 'arr'):
                    write_array_packed(dut, 'arr', arr, DATA_WIDTH)
                else:
                    # Try arr[0] style (Pythonic list port)
                    for idx, val in enumerate(arr):
                        dut.arr[idx].value = clamp_to_width(val, DATA_WIDTH)
                
                # Write x and len
                dut.x.value = clamp_to_width(x, DATA_WIDTH)
                dut.len.value = clamp_to_width(len(arr), LEN_WIDTH)
                
                # Start search
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, 100)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result = int(dut.result.value)
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
                
                passed += 1
                cocotb.log.info(f"  Result: {result} ✓")
                
                # Wait one cycle for next test
                await RisingEdge(dut.clk)
            else:
                # Combinational - just apply and check
                for idx, val in enumerate(arr):
                    dut.arr[idx].value = clamp_to_width(val, DATA_WIDTH)
                dut.x.value = clamp_to_width(x, DATA_WIDTH)
                dut.len.value = clamp_to_width(len(arr), LEN_WIDTH)
                await Timer(50, units='ns')
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result = int(dut.result.value)
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
                
                passed += 1
                cocotb.log.info(f"  Result: {result} ✓")
        
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"\nTest Summary: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} tests failed")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test specific edge cases"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test: Array with duplicates at boundary
    arr = [1, 2, 2, 3, 3, 3, 4, 5]
    x = 2
    expected = 1
    
    cocotb.log.info(f"Test: Duplicates - arr={arr}, x={x}")
    
    if is_seq:
        for idx, val in enumerate(arr):
            dut.arr[idx].value = clamp_to_width(val, DATA_WIDTH)
        dut.x.value = clamp_to_width(x, DATA_WIDTH)
        dut.len.value = clamp_to_width(len(arr), LEN_WIDTH)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut, 100)
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Expected {expected}, got {result} for duplicates")
    else:
        for idx, val in enumerate(arr):
            dut.arr[idx].value = clamp_to_width(val, DATA_WIDTH)
        dut.x.value = clamp_to_width(x, DATA_WIDTH)
        dut.len.value = clamp_to_width(len(arr), LEN_WIDTH)
        await Timer(50, units='ns')
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Expected {expected}, got {result} for duplicates")
    
    cocotb.log.info("Edge cases passed ✓")
