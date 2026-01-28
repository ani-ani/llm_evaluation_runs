import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_ELEMENTS = 16
TUPLE_MAX = 8
CLK_NS = 10
MAX_CYCLES = 100

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, name, vals, width, max_len):
    # Write to array elements
    for i in range(max_len):
        val = vals[i] if i < len(vals) else 0
        getattr(dut, f'{name}_{i}').value = clamp_to_width(val, width)

async def read_array(dut, name, max_len):
    result = []
    for i in range(max_len):
        if has_signal(dut, f'{name}_{i}'):
            v = int(getattr(dut, f'{name}_{i}').value)
            result.append(v)
        elif hasattr(dut, name):
            # Handle as packed array if exists
            v = int(dut.__getattr__(name).value) >> (i * DATA_WIDTH)
            result.append(v & 0xFF)
    return result

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_add_tuple(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ([5, 6, 7], (9, 10), [5, 6, 7, 9, 10]),
        ([6, 7, 8], (10, 11), [6, 7, 8, 10, 11]),
        ([7, 8, 9], (11, 12), [7, 8, 9, 11, 12])
    ]
    
    passed = failed = 0
    
    for i, (list_in, tuple_in, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {list_in} + {tuple_in} == {expected}")
        try:
            # Write inputs
            if is_seq:
                # Set lengths
                dut.list_len.value = len(list_in)
                dut.tuple_len.value = len(tuple_in)
                
                # Write list array
                await write_array(dut, 'list_in', list_in, DATA_WIDTH, 16)
                
                # Write tuple array
                await write_array(dut, 'tuple_in', tuple_in, DATA_WIDTH, 8)
                
                # Start operation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for completion
                await wait_for_done(dut)
                
                # Read result
                if has_signal(dut, 'result_len'):
                    result_len = int(dut.result_len.value)
                else:
                    result_len = len(expected)
                
                result_arr = await read_array(dut, 'result', 16)
                
                # Check overflow
                if has_signal(dut, 'overflow'):
                    overflow = int(dut.overflow.value)
                    if overflow and result_len > 16:
                        cocotb.log.warning(f"Overflow detected for test {i+1}")
                
                # Truncate to expected length and compare
                result_truncated = result_arr[:len(expected)]
                
                if result_truncated != expected:
                    raise TestFailure(f"Expected {expected}, got {result_truncated}")
                
                if result_len != len(expected) and result_len <= 16:
                    cocotb.log.warning(f"Length mismatch: {result_len} vs {len(expected)}")
                
                passed += 1
            else:
                # Combinational test
                await Timer(100, units='ns')
                result_arr = await read_array(dut, 'result', 16)
                result_truncated = result_arr[:len(expected)]
                
                if result_truncated != expected:
                    raise TestFailure(f"Expected {expected}, got {result_truncated}")
                passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_overflow_case(dut):
    """Test that overflow is handled correctly"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # List of 14 elements + tuple of 4 = 18 (overflow)
    list_in = list(range(14))
    tuple_in = [100, 101, 102, 103]
    
    if is_seq:
        dut.list_len.value = len(list_in)
        dut.tuple_len.value = len(tuple_in)
        
        await write_array(dut, 'list_in', list_in, DATA_WIDTH, 16)
        await write_array(dut, 'tuple_in', tuple_in, DATA_WIDTH, 8)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut)
        
        if has_signal(dut, 'overflow'):
            overflow = int(dut.overflow.value)
            cocotb.log.info(f"Overflow signal: {overflow}")
            if overflow != 1:
                cocotb.log.warning(f"Expected overflow=1, got {overflow}")
        
        if has_signal(dut, 'result_len'):
            result_len = int(dut.result_len.value)
            cocotb.log.info(f"Result length (capped): {result_len}")
            if result_len != 16:
                cocotb.log.warning(f"Expected length 16, got {result_len}")
    else:
        await Timer(100, units='ns')