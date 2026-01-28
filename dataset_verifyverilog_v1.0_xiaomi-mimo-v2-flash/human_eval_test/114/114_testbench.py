import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'data_valid'): dut.data_valid.value = 0
    if has_signal(dut, 'data_end'): dut.data_end.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def compute_min_subarray_sum(nums):
    """Kadane's algorithm for minimum subarray sum"""
    if not nums:
        return 0
    min_sum = nums[0]
    current_sum = 0
    for num in nums:
        current_sum += num
        min_sum = min(min_sum, current_sum)
        if current_sum > 0:
            current_sum = 0
    return min_sum

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_subarray_sum(dut):
    """Test minimum subarray sum calculation"""
    
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        CLK_NS = 10
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    DATA_WIDTH = 16
    MAX_ELEMENTS = 16
    
    # Test cases: (input_array, expected_result, description)
    test_cases = [
        ([2, 3, 4, 1, 2, 4], 1, "positive array, min is 1"),
        ([-1, -2, -3], -6, "all negative"),
        ([-1, -2, -3, 2, -10], -14, "mixed with negative peak"),
        ([-10], -10, "single negative"),
        ([7], 7, "single positive"),
        ([1, -1], -1, "positive then negative"),
        ([0, 10, 20, 1000000], 0, "includes zero"),
        ([-1, -2, -3, 10, -5], -6, "negative sum"),
        ([100, -1, -2, -3, 10, -5], -6, "large positive start"),
        ([10, 11, 13, 8, 3, 4], 3, "all positive, min is 3"),
        ([100, -33, 32, -1, 0, -2], -33, "various values"),
    ]
    
    passed = 0
    failed = 0
    
    for idx, (nums, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}/{len(test_cases)}: {desc}")
        
        # Clamp values to 16-bit signed range
        nums_clamped = [to_signed(clamp_to_width(v & 0xFFFF, DATA_WIDTH), DATA_WIDTH) for v in nums]
        
        try:
            if not is_seq:
                # Combinational - just compute directly
                dut.n.value = len(nums)
                for i, v in enumerate(nums_clamped[:MAX_ELEMENTS]):
                    if hasattr(dut, f'arr_{i}'):
                        getattr(dut, f'arr_{i}').value = v & 0xFFFF
                    elif hasattr(dut, 'arr') and hasattr(dut.arr, '__len__'):
                        try:
                            dut.arr[i].value = v & 0xFFFF
                        except:
                            pass
                await Timer(100, units='ns')
            else:
                # Sequential - stream inputs
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Stream data
                for num in nums_clamped:
                    dut.data_in.value = num & 0xFFFF
                    dut.data_valid.value = 1
                    await RisingEdge(dut.clk)
                
                # End of data
                dut.data_valid.value = 0
                dut.data_end.value = 1
                await RisingEdge(dut.clk)
                dut.data_end.value = 0
                
                # Wait for done
                await wait_for_done(dut, max_cycles=200)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            # Convert back to signed for comparison
            result_signed = to_signed(result, DATA_WIDTH)
            
            if result_signed != expected:
                raise TestFailure(f"Expected {expected}, got {result_signed}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result_signed}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Additional: Test with maximum elements
    cocotb.log.info(f"\nTest edge: MAX_ELEMENTS ({MAX_ELEMENTS})")
    max_test_nums = list(range(-MAX_ELEMENTS, 0))  # All negative
    max_test_expected = compute_min_subarray_sum(max_test_nums)
    
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        for i, num in enumerate(max_test_nums):
            dut.data_in.value = to_signed(clamp_to_width(num & 0xFFFF, DATA_WIDTH), DATA_WIDTH) & 0xFFFF
            dut.data_valid.value = 1
            await RisingEdge(dut.clk)
        
        dut.data_valid.value = 0
        dut.data_end.value = 1
        await RisingEdge(dut.clk)
        dut.data_end.value = 0
        
        await wait_for_done(dut, max_cycles=300)
        
        if is_value_defined(dut.result.value):
            result = int(dut.result.value)
            result_signed = to_signed(result, DATA_WIDTH)
            if result_signed == max_test_expected:
                passed += 1
                cocotb.log.info(f"  PASS: max_elements result={result_signed}")
            else:
                cocotb.log.error(f"  FAIL: max_elements expected {max_test_expected}, got {result_signed}")
                failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"\nAll tests passed ({passed}/{passed+failed})")
