import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 100

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1 << bits) - 1)) << (i * bits)
    return r

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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_check_none(dut):
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases
    test_cases = [
        # (array_values, len, expected_result, description)
        # Test 1: Contains None (0xFF)
        ([10, 4, 5, 6, 0xFF, 0, 0, 0], 5, 1, "Contains None at index 4"),
        # Test 2: No None
        ([7, 8, 9, 11, 14, 0, 0, 0], 5, 0, "No None values"),
        # Test 3: Contains None at end
        ([1, 2, 3, 4, 0xFF, 0, 0, 0], 5, 1, "Contains None at index 4"),
        # Test 4: None at beginning
        ([0xFF, 10, 20, 30, 0, 0, 0, 0], 4, 1, "None at index 0"),
        # Test 5: All None
        ([0xFF, 0xFF, 0xFF, 0xFF, 0, 0, 0, 0], 4, 1, "All None"),
        # Test 6: Empty array (len=0)
        ([0, 0, 0, 0, 0, 0, 0, 0], 0, 0, "Empty array"),
        # Test 7: Single element, is None
        ([0xFF, 0, 0, 0, 0, 0, 0, 0], 1, 1, "Single None"),
        # Test 8: Single element, valid
        ([42, 0, 0, 0, 0, 0, 0, 0], 1, 0, "Single valid"),
        # Test 9: All valid, full array
        ([1, 2, 3, 4, 5, 6, 7, 8], 8, 0, "Full array valid"),
        # Test 10: Edge value (0xFE - max valid)
        ([0xFE, 0xFE, 0xFE, 0, 0, 0, 0, 0], 3, 0, "Max valid values"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_vals, length, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - Expected: {expected}")
        
        try:
            # Write array values
            if is_seq and has_signal(dut, 'arr'):
                # Check if arr is array or individual signals
                if hasattr(dut.arr, '__len__'):
                    for idx in range(ARRAY_SIZE):
                        val = arr_vals[idx] if idx < len(arr_vals) else 0
                        dut.arr[idx].value = clamp_to_width(val, DATA_WIDTH)
                else:
                    # Pack into single port if packed
                    packed = pack_array(arr_vals, DATA_WIDTH)
                    dut.arr.value = packed
            elif is_seq:
                # Handle individual arr_0, arr_1... signals
                for idx in range(ARRAY_SIZE):
                    sig_name = f'arr_{idx}'
                    if has_signal(dut, sig_name):
                        val = arr_vals[idx] if idx < len(arr_vals) else 0
                        getattr(dut, sig_name).value = clamp_to_width(val, DATA_WIDTH)
            
            # Set len
            if has_signal(dut, 'len'):
                dut.len.value = clamp_to_width(length, 4)
            
            # Start computation
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational
                await Timer(10, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"Test {i+1} passed")
            
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} FAILED: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n=== Summary ===")
    cocotb.log.info(f"Passed: {passed}/{len(test_cases)}")
    cocotb.log.info(f"Failed: {failed}/{len(test_cases)}")
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
