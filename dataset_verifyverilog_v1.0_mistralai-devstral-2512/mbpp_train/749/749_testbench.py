import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 1000

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Convert Python test strings to 8-bit signed integers
def convert_test_strings(strings):
    nums = [int(s.strip()) for s in strings]
    return [to_signed(n, DATA_WIDTH) for n in nums]

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        if i < ARRAY_SIZE:
            dut.__getattr__(name)[i].value = clamp_to_width(v, width)

async def read_array(dut, name, width):
    result = []
    for i in range(ARRAY_SIZE):
        val = int(dut.__getattr__(name)[i].value)
        # Convert from unsigned representation to signed
        if val >= (1 << (width-1)):
            val -= (1 << width)
        result.append(val)
    return result

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_numeric_string_sorting(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from Python problem (converted to signed 8-bit)
    test_cases = [
        # Test 1: [-500, -12, 0, 4, 7, 12, 45, 100, 200]
        (['4','12','45','7','0','100','200','-12','-500'], [-500, -12, 0, 4, 7, 12, 45, 100, 200], "Test 1: Basic negatives and positives"),
        # Test 2: [1,1,1,2,2,2,2,3,3,4,4,5,6,6,6,7,8,8,9,9]
        (['2','3','8','4','7','9','8','2','6','5','1','6','1','2','3','4','6','9','1','2'], 
         [1,1,1,2,2,2,2,3,3,4,4,5,6,6,6,7,8,8,9,9], "Test 2: Duplicates and 20 elements"),
        # Test 3: [1,1,1,3,3,5,5,7,7,9,11,13,15,17]
        (['1','3','5','7','1','3','13','15','17','5','7','9','1','11'],
         [1,1,1,3,3,5,5,7,7,9,11,13,15,17], "Test 3: Mixed lengths"),
        # Additional edge cases
        (['1'], [1], "Single element"),
        (['127', '-128'], [-128, 127], "Min/Max 8-bit"),
        (['0', '-1', '1'], [-1, 0, 1], "Zero and symmetric"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_strs, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {desc}")
        
        # Handle case where test has more than 16 elements (slice to fit)
        if len(input_strs) > ARRAY_SIZE:
            input_strs = input_strs[:ARRAY_SIZE]
            expected = sorted([int(s) for s in input_strs])[:ARRAY_SIZE]
            cocotb.log.warning(f"  Input truncated to {ARRAY_SIZE} elements")
        
        try:
            # Convert input strings to signed integers
            input_ints = convert_test_strings(input_strs)
            
            # Write input array
            await write_array(dut, 'arr_in', input_ints, DATA_WIDTH)
            
            # Set length (clamp to array size)
            length = min(len(input_strs), ARRAY_SIZE)
            if has_signal(dut, 'len'):
                dut.len.value = clamp_to_width(length, 4)
            else:
                cocotb.log.warning("  'len' signal not found, assuming full array")
            
            # Start sorting
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, MAX_CYCLES)
            else:
                # Combinational case
                await Timer(100, units='ns')
            
            # Read output
            if has_signal(dut, 'arr_out'):
                output_ints = await read_array(dut, 'arr_out', DATA_WIDTH)
            else:
                raise TestFailure("arr_out signal not found")
            
            # Verify result (only compare first 'length' elements)
            result_sorted = [x for x in output_ints if x != 0 or i == 0]  # Filter zeros
            result_sorted = result_sorted[:length]
            
            # Handle overflow values in expected (clamp to 8-bit signed)
            clamped_expected = [to_signed(to_signed(x, DATA_WIDTH), DATA_WIDTH) for x in expected]
            
            cocotb.log.info(f"  Input:  {input_strs}")
            cocotb.log.info(f"  Expected: {clamped_expected}")
            cocotb.log.info(f"  Got:      {result_sorted}")
            
            # Compare
            if result_sorted == clamped_expected:
                cocotb.log.info(f"  ✓ PASS")
                passed += 1
            else:
                raise TestFailure(f"Mismatch: expected {clamped_expected}, got {result_sorted}")
                
        except TestFailure as e:
            cocotb.log.error(f"  ✗ FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"\n{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"\n=== ALL TESTS PASSED ===")
    cocotb.log.info(f"Total: {passed + failed}, Passed: {passed}, Failed: {failed}")