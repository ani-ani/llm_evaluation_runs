import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    if v < 0: v = (1 << bits) + v
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_array_signed(dut, arr_name, values, width, max_len=16):
    """Write signed values to array elements"""
    for i, v in enumerate(values[:max_len]):
        signed_val = from_signed(v, width)
        getattr(dut, f'{arr_name}_{i}').value = clamp_to_width(signed_val, width)
    # Zero out remaining elements
    for i in range(len(values[:max_len]), max_len):
        getattr(dut, f'{arr_name}_{i}').value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_sum_negative(dut):
    CLK_NS = 10
    DATA_WIDTH = 8
    ARRAY_SIZE = 16
    ACCUM_WIDTH = 16
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (input_list, expected_sum, description)
    test_cases = [
        ([2, 4, -6, -9, 11, -12, 14, -5, 17], -32, "Original test 1"),
        ([10, 15, -14, 13, -18, 12, -20], -52, "Original test 2"),
        ([19, -65, 57, 39, 152, -639, 121, 44, 90, -190], -894, "Original test 3")
    ]
    
    passed = 0
    failed = 0
    
    for idx, (input_nums, expected_sum, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {idx+1}: {desc}")
        cocotb.log.info(f"  Input: {input_nums}")
        cocotb.log.info(f"  Expected: {expected_sum}")
        
        try:
            # Write input array (signed 8-bit)
            await write_array_signed(dut, 'arr', input_nums, DATA_WIDTH, ARRAY_SIZE)
            
            # Set length
            dut.len.value = len(input_nums)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=100)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = to_signed(int(dut.result.value), ACCUM_WIDTH)
            
            if result != expected_sum:
                raise TestFailure(f"Expected {expected_sum}, got {result}")
            
            cocotb.log.info(f"  Got: {result} - PASS")
            passed += 1
            
            # Wait a cycle before next test
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            
    if failed:
        raise TestFailure(f"{failed} test(s) failed, {passed} passed")
    else:
        cocotb.log.info(f"\nAll {passed} tests passed!")
