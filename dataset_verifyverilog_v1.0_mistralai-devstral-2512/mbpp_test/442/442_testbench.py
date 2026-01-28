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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Fixed-point conversion
def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

# Expected result calculator for Q8.8
def expected_ratio_q88(nums):
    pos = sum(1 for x in nums if x > 0)
    n = len(nums)
    if n == 0:
        return 0
    # Q8.8: (pos * 256) / n
    return (pos * 256) // n

# Testbench
DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 200

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_positive_ratio(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational - just set inputs
        dut.rst_n.value = 1
        dut.start.value = 0
    
    # Test cases
    test_cases = [
        ([0, 1, 2, -1, -5, 6, 0, -3, -2, 3, 4, 6, 8], 13, "Mixed with zeros"),
        ([2, 1, 2, -1, -5, 6, 4, -3, -2, 3, 4, 6, 8], 13, "More positives"),
        ([2, 4, -6, -9, 11, -12, 14, -5, 17], 9, "5 positives")
    ]
    
    passed = 0
    failed = 0
    
    for idx, (nums, expected_len, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: {desc}")
        cocotb.log.info(f"Input: {nums}, Length: {expected_len}")
        
        try:
            # Set array elements individually
            for i in range(ARRAY_SIZE):
                val = nums[i] if i < len(nums) else 0
                # Convert to unsigned for assignment, handle signed properly
                if has_signal(dut, f'arr_{i}'):
                    getattr(dut, f'arr_{i}').value = clamp_to_width(from_signed(val, DATA_WIDTH), DATA_WIDTH)
                elif has_signal(dut, 'arr'):
                    # Direct array indexing
                    dut.arr[i].value = clamp_to_width(from_signed(val, DATA_WIDTH), DATA_WIDTH)
                else:
                    # Packed array or other structure - log warning
                    cocotb.log.warning(f"Cannot set array element {i}")
            
            # Set length
            if has_signal(dut, 'len'):
                dut.len.value = expected_len
            
            if is_seq:
                # Start operation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                max_wait = MAX_CYCLES
                for _ in range(max_wait):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                else:
                    raise TestFailure(f"Timeout waiting for done signal")
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                    
                result_val = int(dut.result.value)
            else:
                # Combinational - just wait a bit for propagation
                await Timer(100, units='ns')
                result_val = int(dut.result.value)
            
            # Calculate expected
            expected = expected_ratio_q88(nums)
            
            # Compare with tolerance for fixed-point rounding
            diff = abs(result_val - expected)
            if diff > 2:  # Allow 2/256 ≈ 0.008 tolerance
                raise TestFailure(f"Expected Q8.8={expected} ({fixed_to_float(expected,8):.4f}), got {result_val} ({fixed_to_float(result_val,8):.4f})")
            
            cocotb.log.info(f"Result: {result_val} ({fixed_to_float(result_val,8):.4f}), Expected: {expected} ({fixed_to_float(expected,8):.4f})")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")

# Additional edge case tests
@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_edge_cases(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test all positive
    cocotb.log.info("Test all positive: [1,2,3,4,5]")
    for i in range(5):
        if has_signal(dut, f'arr_{i}'):
            getattr(dut, f'arr_{i}').value = from_signed(1 + i, DATA_WIDTH)
        elif has_signal(dut, 'arr'):
            dut.arr[i].value = from_signed(1 + i, DATA_WIDTH)
    if has_signal(dut, 'len'):
        dut.len.value = 5
    
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        max_wait = 50
        for _ in range(max_wait):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        result_val = int(dut.result.value)
    else:
        await Timer(100, units='ns')
        result_val = int(dut.result.value)
    
    # Expected: 5/5 = 1.0 → Q8.8 = 256
    expected = 256
    if result_val != expected:
        raise TestFailure(f"All positive: Expected {expected}, got {result_val}")
    cocotb.log.info(f"All positive result: {result_val} ({fixed_to_float(result_val,8):.4f})")
    
    # Test no positives (all zero or negative)
    cocotb.log.info("Test no positives: [0,-1,-2,-3,-4]")
    for i in range(5):
        val = 0 if i == 0 else -(i)
        if has_signal(dut, f'arr_{i}'):
            getattr(dut, f'arr_{i}').value = from_signed(val, DATA_WIDTH)
        elif has_signal(dut, 'arr'):
            dut.arr[i].value = from_signed(val, DATA_WIDTH)
    if has_signal(dut, 'len'):
        dut.len.value = 5
    
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        max_wait = 50
        for _ in range(max_wait):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        result_val = int(dut.result.value)
    else:
        await Timer(100, units='ns')
        result_val = int(dut.result.value)
    
    expected = 0
    if result_val != expected:
        raise TestFailure(f"No positives: Expected {expected}, got {result_val}")
    cocotb.log.info(f"No positives result: {result_val}")
