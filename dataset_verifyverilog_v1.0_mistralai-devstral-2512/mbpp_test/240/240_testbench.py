import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 1000

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    mask = (1 << bits) - 1
    return int(v) & mask

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def write_array(dut, prefix, vals, width):
    """Write list values to individual signals"""
    for i, v in enumerate(vals):
        if i < ARRAY_SIZE:
            getattr(dut, f'{prefix}_{i}').value = clamp_to_width(v, width)

async def read_array(dut, prefix, count):
    """Read array values from individual signals"""
    result = []
    for i in range(min(count, ARRAY_SIZE)):
        val = getattr(dut, f'{prefix}_{i}').value
        if is_value_defined(val):
            result.append(int(val))
    return result

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_replace_list(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Check required signals exist
    if not has_signal(dut, 'start') or not has_signal(dut, 'done'):
        raise TestFailure("Missing required signals: start and done")
    
    # Reset DUT
    await reset_dut(dut)
    
    # Test cases: (in1, in2, expected_result)
    test_cases = [
        ([1, 3, 5, 7, 9, 10], [2, 4, 6, 8], [1, 3, 5, 7, 9, 2, 4, 6, 8]),
        ([1, 2, 3, 4, 5], [5, 6, 7, 8], [1, 2, 3, 4, 5, 6, 7, 8]),
        ([1, 2, 3, 4, 5, 6, 7, 8], [9], [1, 2, 3, 4, 5, 6, 7, 9])
    ]
    
    passed = 0
    failed = 0
    
    for i, (in1_vals, in2_vals, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: in1={in1_vals}, in2={in2_vals}")
        
        try:
            # Calculate expected output length (capped at 8)
            len1 = len(in1_vals)
            len2 = len(in2_vals)
            expected_len = min(8, len1 - 1 + len2)
            
            # Prepare expected result (capped to 8 elements)
            expected_result = []
            # Take first len1-1 elements from in1
            for j in range(min(len1-1, 8)):
                expected_result.append(clamp_to_width(in1_vals[j], DATA_WIDTH))
            # Add all elements from in2 (capped to fill to 8)
            remaining = 8 - len(expected_result)
            for j in range(min(len2, remaining)):
                expected_result.append(clamp_to_width(in2_vals[j], DATA_WIDTH))
            
            # Pad to 8 elements if needed
            while len(expected_result) < 8:
                expected_result.append(0)
            
            # Write input arrays
            await write_array(dut, 'in1', in1_vals, DATA_WIDTH)
            await write_array(dut, 'in2', in2_vals, DATA_WIDTH)
            
            # Write lengths (clamped to 4 bits)
            if has_signal(dut, 'len1'):
                dut.len1.value = clamp_to_width(len1, 4)
            if has_signal(dut, 'len2'):
                dut.len2.value = clamp_to_width(len2, 4)
            
            # Start the operation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=50)
            
            # Read result array
            result = await read_array(dut, 'result', 8)
            
            # Verify result length (first 8 elements)
            if len(result) != 8:
                raise TestFailure(f"Result length mismatch: expected 8, got {len(result)}")
            
            # Verify values match expected (first expected_len elements)
            for j in range(expected_len):
                if j < len(result):
                    if result[j] != expected_result[j]:
                        raise TestFailure(f"Index {j}: expected {expected_result[j]}, got {result[j]}")
            
            cocotb.log.info(f"Result: {result[:expected_len]}")
            cocotb.log.info(f"Expected: {expected_result[:expected_len]}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL - Test {i+1}: {e}")
            failed += 1
    
    cocotb.log.info(f"\nTotal tests: {len(test_cases)}")
    cocotb.log.info(f"Passed: {passed}")
    cocotb.log.info(f"Failed: {failed}")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")