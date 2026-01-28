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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Compute expected result in Python
def compute_expected(nums):
    count = 0
    for n in nums:
        # Check > 10
        if n <= 10:
            continue
        # Get absolute value, handle edge case
        abs_n = abs(n)
        # Special case: abs(-32768) = 32768 which overflows 16-bit
        if abs_n > 32767:
            abs_n = 32767
        # Get digits
        if abs_n < 10:
            continue
        first_digit = abs_n % 10
        last_digit = (abs_n // 10) % 10
        # Check both odd
        if (first_digit & 1) and (last_digit & 1):
            count += 1
    return count

async def write_nums_array(dut, nums):
    """Write 16 elements to nums array, pad with zeros if needed"""
    # Pad to 16 elements
    padded = nums[:16] + [0] * (16 - len(nums[:16]))
    
    # Write to nums[0][15:0]...nums[15][15:0]
    for i in range(16):
        val = padded[i]
        # Clamp to 16-bit signed range for writing
        if val < -32768:
            val = -32768
        elif val > 32767:
            val = 32767
        # Convert to unsigned for assignment
        unsigned_val = from_signed(val, 16)
        # Try individual port access
        port_name = f'nums_{i}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = unsigned_val
        else:
            # Try array access
            dut.nums[i].value = unsigned_val

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_special_filter(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        ([5, -2, 1, -5], 0, "small numbers"),
        ([15, -73, 14, -15], 1, "example 1"),
        ([33, -2, -3, 45, 21, 109], 2, "example 2"),
        ([43, -12, 93, 125, 121, 109], 4, "example 3"),
        ([71, -2, -33, 75, 21, 19], 3, "example 4"),
        ([1], 0, "single element"),
        ([], 0, "empty array"),
        ([-15, 15, 10, 11], 1, "mixed negative"),
    ]
    
    passed = failed = 0
    
    for i, (nums, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - nums={nums}")
        
        try:
            await write_nums_array(dut, nums)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read result
            result_sig = dut.count if has_signal(dut, 'count') else dut.result
            if not is_value_defined(result_sig.value):
                raise TestFailure("Result signal undefined")
            
            result = int(result_sig.value)
            
            # Compute expected (Python reference)
            computed = compute_expected(nums)
            
            if result != computed:
                raise TestFailure(f"Expected {computed}, got {result}")
            if result != expected:
                raise TestFailure(f"Problem expected {expected}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            # Continue with other tests
        
        # Small delay between tests
        if is_seq:
            await RisingEdge(dut.clk)
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")
    
    cocotb.log.info(f"All tests passed: {passed}")

# Additional test for edge cases with large numbers
@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_large_numbers(dut):
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test with edge case: -32768 (abs overflows)
    test_cases = [
        ([32767, -32768, 1001, 9999], 2, "large numbers"),  # 1001 and 9999 should count
        ([100, 200, 300, 400], 0, "even digits"),
        ([1111, 3333, 5555, 7777], 4, "all odd digits"),
    ]
    
    for nums, expected, desc in test_cases:
        cocotb.log.info(f"Edge test: {desc}")
        await write_nums_array(dut, nums)
        
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            await Timer(100, units='ns')
        
        result_sig = dut.count if has_signal(dut, 'count') else dut.result
        result = int(result_sig.value)
        computed = compute_expected(nums)
        
        if result != computed:
            raise TestFailure(f"{desc}: Expected {computed}, got {result}")