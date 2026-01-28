import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 16
LEN_WIDTH = 4
RESULT_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 100

# Helper functions
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
    max_val = (1 << bits) - 1
    if v < 0:
        return 0
    return v if v <= max_val else max_val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    """Reset the DUT synchronously"""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal or timeout"""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, values):
    """Write array values to DUT with proper indexing"""
    # Write to individual elements if array indexing is available
    try:
        for i, val in enumerate(values):
            if i < ARRAY_SIZE:
                dut.arr[i].value = clamp_to_width(val, DATA_WIDTH)
        # Zero out remaining elements
        for i in range(len(values), ARRAY_SIZE):
            dut.arr[i].value = 0
    except AttributeError:
        # Try individual ports arr_0, arr_1, etc.
        for i in range(ARRAY_SIZE):
            val = values[i] if i < len(values) else 0
            port_name = f'arr_{i}'
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
            else:
                break

def count_even_xor_pairs(arr):
    """Reference Python implementation"""
    count = 0
    n = len(arr)
    for i in range(n):
        for j in range(i+1, n):
            if ((arr[i] ^ arr[j]) % 2) == 0:
                count += 1
    return count

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_even_pair_counter(dut):
    """Test the even XOR pair counter module"""
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Initial reset
    await reset_dut(dut)
    
    # Test cases: (input_array, expected_count, description)
    test_cases = [
        ([5, 4, 7, 2, 1], 4, "Test 1: mixed parity"),
        ([7, 2, 8, 1, 0, 5, 11], 9, "Test 2: multiple pairs"),
        ([1, 2, 3], 1, "Test 3: small array"),
        ([2, 4, 6, 8], 6, "Test 4: all even (C(4,2)=6)"),
        ([1, 3, 5, 7], 6, "Test 5: all odd (C(4,2)=6)"),
        ([1, 2], 0, "Test 6: single pair mismatched"),
        ([1, 3], 1, "Test 7: single pair matched"),
        ([0, 0, 0], 3, "Test 8: all zero"),
        ([], 0, "Test 9: empty array"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (inp, expected, desc) in enumerate(test_cases, 1):
        cocotb.log.info(f"\nTest {test_idx}: {desc}")
        cocotb.log.info(f"  Input: {inp}, Expected: {expected}")
        
        try:
            # Verify reference calculation
            reference = count_even_xor_pairs(inp)
            if reference != expected:
                cocotb.log.warning(f"  Warning: Reference gives {reference}, expected {expected}")
            
            # Write input array
            await write_array(dut, inp)
            
            # Write length
            dut.len.value = len(inp) & 0xF  # 4-bit width
            
            # Start calculation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal is undefined")
            
            result = int(dut.result.value)
            cocotb.log.info(f"  Result: {result}")
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"  ERROR: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n=== Summary ===")
    cocotb.log.info(f"Passed: {passed}/{len(test_cases)}")
    cocotb.log.info(f"Failed: {failed}/{len(test_cases)}")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
