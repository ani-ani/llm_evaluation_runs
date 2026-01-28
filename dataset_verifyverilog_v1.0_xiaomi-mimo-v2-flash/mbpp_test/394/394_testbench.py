import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_ELEMENTS = 16
CLK_NS = 10
MAX_CYCLES = 256

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_array(dut, values, width=DATA_WIDTH, max_len=MAX_ELEMENTS):
    # Validate input length
    if len(values) > max_len:
        raise ValueError(f"Array length {len(values)} exceeds max {max_len}")
    
    # Write each element to individual port
    for i in range(max_len):
        port_name = f'arr_{i}'
        if has_signal(dut, port_name):
            if i < len(values):
                val = clamp_to_width(values[i], width)
                getattr(dut, port_name).value = val
            else:
                getattr(dut, port_name).value = 0

async def write_len(dut, length):
    dut.len.value = clamp_to_width(length, 4)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_check_distinct(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational - just apply inputs
        await Timer(10, units='ns')
    
    # Test cases from Python function
    test_cases = [
        ([1, 4, 5, 6, 1, 4], 0, "Test 1: duplicates found"),
        ([1, 4, 5, 6], 1, "Test 2: all unique"),
        ([2, 3, 4, 5, 6], 1, "Test 3: all unique"),
        ([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], 1, "Test 4: 16 unique values"),
        ([0, 0, 0], 0, "Test 5: all same values"),
        ([255], 1, "Test 6: single element"),
        ([10, 20, 30, 10], 0, "Test 7: duplicate at end"),
        ([42, 42, 43], 0, "Test 8: duplicate at start"),
        ([100, 200, 150, 50], 1, "Test 9: unsorted unique"),
        ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 0], 1, "Test 10: 16 unique rotated"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_array, expected_result, description) in enumerate(test_cases):
        cocotb.log.info(f"Running Test {i+1}: {description}")
        try:
            if is_seq:
                # Write array and length
                await write_array(dut, test_array)
                await write_len(dut, len(test_array))
                
                # Trigger start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for completion
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                
                actual = int(dut.result.value)
            else:
                # Combinational logic
                await write_array(dut, test_array)
                await write_len(dut, len(test_array))
                await Timer(100, units='ns')
                actual = int(dut.result.value)
            
            if actual != expected_result:
                raise TestFailure(f"Expected {expected_result}, got {actual}")
            
            passed += 1
            cocotb.log.info(f"PASS: {description} - result={actual}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {description} - {e}")
            failed += 1
    
    cocotb.log.info(f"\nTest Summary: {passed}/{len(test_cases)} passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")