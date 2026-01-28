import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
RESULT_WIDTH = 16
ARRAY_SIZE = 10
CLK_NS = 10
MAX_CYCLES = 100

# MANDATORY HELPERS
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

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

# Helper to compute expected result
def compute_expected(nums, exponent, valid_mask):
    results = []
    for i in range(ARRAY_SIZE):
        if (valid_mask >> i) & 1:
            if exponent == 0:  # x^2
                val = nums[i] * nums[i]
            elif exponent == 1:  # x^3
                val = nums[i] * nums[i] * nums[i]
            elif exponent == 2:  # x^5
                sq = nums[i] * nums[i]
                val = sq * sq * nums[i]
            else:
                val = 0
            # Clamp to 16 bits
            results.append(clamp_to_width(val, RESULT_WIDTH))
        else:
            results.append(0)
    return results

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_pow_array(dut):
    # Check if sequential or combinatorial
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases
    test_cases = [
        # nums, exponent (0=2, 1=3, 2=5), valid_mask, description
        (list(range(1, 11)), 0, 0x3FF, "1-10, x^2"),  # All valid
        ([10, 20, 30], 1, 0x007, "10,20,30, x^3"),  # First 3 valid
        ([12, 15], 2, 0x003, "12,15, x^5"),         # First 2 valid
        ([255], 1, 0x001, "255, x^3 (overflow)"),   # Overflow test
        ([0], 0, 0x001, "0, x^2 (zero)"),           # Zero test
        ([31], 2, 0x001, "31, x^5 (large)"),        # Large value
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (nums, exponent, valid_mask, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx+1}: {desc}")
        
        # Prepare input array
        input_array = [0] * ARRAY_SIZE
        for i, num in enumerate(nums):
            if i < ARRAY_SIZE:
                input_array[i] = clamp_to_width(num, DATA_WIDTH)
        
        expected = compute_expected(nums, exponent, valid_mask)
        
        try:
            # Write inputs
            if has_signal(dut, 'nums'):
                for i in range(ARRAY_SIZE):
                    if hasattr(dut.nums[i], 'value'):
                        dut.nums[i].value = input_array[i]
                    else:
                        # Try array indexing
                        dut.nums[i].value = input_array[i]
            
            # Write exponent
            if has_signal(dut, 'exponents'):
                dut.exponents.value = exponent
            
            # Write valid mask
            if has_signal(dut, 'valid_in'):
                dut.valid_in.value = valid_mask
            
            # Start computation
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(200, units='ns')
            
            # Read results
            if not has_signal(dut, 'results'):
                raise TestFailure("Output signal 'results' not found")
            
            results = []
            for i in range(ARRAY_SIZE):
                if hasattr(dut.results[i], 'value'):
                    results.append(safe_int(dut.results[i].value))
                else:
                    results.append(0)
            
            # Read valid_out
            valid_out = 0
            if has_signal(dut, 'valid_out'):
                valid_out = safe_int(dut.valid_out.value)
            
            # Validate
            for i in range(ARRAY_SIZE):
                if (valid_mask >> i) & 1:
                    if (valid_out >> i) & 1:
                        if results[i] != expected[i]:
                            raise TestFailure(
                                f"Element {i}: Expected {expected[i]}, got {results[i]}"
                            )
                    else:
                        raise TestFailure(f"Element {i}: valid_out not set")
                else:
                    if (valid_out >> i) & 1:
                        raise TestFailure(f"Element {i}: valid_out set for invalid input")
                    if results[i] != 0:
                        raise TestFailure(f"Element {i}: Expected 0 for invalid input")
            
            # Check done for sequential
            if is_seq and has_signal(dut, 'done'):
                if int(dut.done.value) != 1:
                    raise TestFailure("done signal not high after computation")
            
            passed += 1
            cocotb.log.info(f"PASSED: {desc}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: Test {test_idx+1} - {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")
