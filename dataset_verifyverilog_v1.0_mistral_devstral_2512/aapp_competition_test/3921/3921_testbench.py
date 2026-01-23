import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# ============================================================================
# PRIME FACTORIZATION FOR TESTBENCH
# ============================================================================
def get_prime_factors(n):
    factors = []
    d = 2
    while d * d <= n:
        if n % d == 0:
            factors.append(d)
            while n % d == 0:
                n //= d
        d += 1
    if n > 1:
        factors.append(n)
    return factors

# ============================================================================
# EXPECTED RESULT COMPUTATION
# ============================================================================
def compute_expected(arr, length):
    dp = [0] * 257  # dp[p] for prime p
    overall_max = 0
    for i in range(length):
        num = arr[i]
        if num == 1:
            current_length = 1
        else:
            factors = get_prime_factors(num)
            max_prev = 0
            for p in factors:
                if dp[p] > max_prev:
                    max_prev = dp[p]
            current_length = max_prev + 1
            for p in factors:
                if current_length > dp[p]:
                    dp[p] = current_length
        if current_length > overall_max:
            overall_max = current_length
    return overall_max

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_good_sequence_finder(dut):
    """Test the GoodSequenceFinder module"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ([2,3,4,6,9], 5, 4),
        ([1,2,3,5,6,7,8,9,10], 9, 4),
        ([1,2,4,6], 4, 3),
        ([1,2,3,4,7,9,10], 7, 3),
        ([1], 1, 1),
        ([3,4,5,6,7,8,9,10], 8, 4),
        ([2,3,7,9,10], 5, 2),
        ([1,4,7], 3, 1),
        ([4], 1, 1),
        ([1,2,3,4,5,6,7,9,10], 9, 4),
    ]
    
    passed = 0
    failed = 0
    
    for arr, length, expected in test_cases:
        # Prepare inputs
        dut.len.value = length
        
        # Set individual array elements with clamping
        for i in range(16):
            val = arr[i] if i < length else 0
            # Use getattr to handle individual ports
            if has_signal(dut, f'arr_{i}'):
                getattr(dut, f'arr_{i}').value = clamp_to_width(val, 8)
            else:
                # Fallback for indexed array
                dut.arr[i].value = clamp_to_width(val, 8)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 100
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure("Timeout waiting for done")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result is undefined")
        
        result = int(dut.result.value)
        
        # Verify
        if result != expected:
            raise TestFailure(f"Input: {arr[:length]}, Expected: {expected}, Got: {result}")
        
        dut._log.info(f"Test passed for {arr[:length]}: result={result}")
        passed += 1
        
        # Reset for next test
        dut.rst_n.value = 0
        await Timer(20, units='ns')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"All tests passed: {passed}/{passed} tests")
