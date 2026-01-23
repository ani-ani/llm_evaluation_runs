import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper to compute GCD
def gcd(a, b):
    while b:
        a, b = b, a % b
    return a

def compute_expected(n, arr):
    # Check for ones
    ones = arr.count(1)
    if ones > 0:
        return n - ones
    
    # Check if possible
    total_gcd = arr[0]
    for x in arr[1:]:
        total_gcd = gcd(total_gcd, x)
    if total_gcd != 1:
        return -1
    
    # Find shortest subarray with GCD 1
    min_len = n
    for i in range(n):
        current_gcd = arr[i]
        for j in range(i + 1, n):
            current_gcd = gcd(current_gcd, arr[j])
            if current_gcd == 1:
                min_len = min(min_len, j - i + 1)
                break
    
    return (min_len - 1) + (n - 1)

@cocotb.test()
async def test_gcd_operations(dut):
    """Test GCD Operations Calculator"""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a_0.value = 0
    dut.a_1.value = 0
    dut.a_2.value = 0
    dut.a_3.value = 0
    dut.a_4.value = 0
    dut.a_5.value = 0
    dut.a_6.value = 0
    dut.a_7.value = 0
    
    for _ in range(5):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (N=8 fixed, inputs scaled to fit)
    # We pad inputs to length 8 or take first 8
    test_cases = [
        # Case 1: [2, 2, 3, 4, 6] -> pad -> expected 5
        ([2, 2, 3, 4, 6, 0, 0, 0], 5),
        # Case 2: [2, 4, 6, 8] -> impossible -> expected -1
        ([2, 4, 6, 8, 0, 0, 0, 0], -1),
        # Case 3: [2, 6, 9] -> expected 4
        ([2, 6, 9, 0, 0, 0, 0, 0], 4),
        # Case 4: All ones -> expected 0
        ([1, 1, 1, 1, 0, 0, 0, 0], 0),
        # Case 5: Mixed, one 1 -> expected 7 (8-1)
        ([1, 2, 3, 4, 5, 6, 7, 8], 7),
        # Case 6: [42, 15, 35] -> GCD is 1, min subarray [15, 35] GCD 5, [42, 15] GCD 3, [42, 15, 35] GCD 1 (len 3). Ops = (3-1)+(8-1) = 9 (Wait, logic is (L-1)+(N-1). N=8. Ops = 2 + 7 = 9? No. Wait. Original N=3. Ops = (3-1)+(3-1)=4. In our case N=8. But we only have 3 active elements. 
        # Let's stick to N=8.
        # If we only care about 3 active elements, result might be misleading if 0s act as identity.
        # Correction: GCD(0, x) = x. 0 is neutral for GCD? No, GCD(0, 0) is 0. GCD(0, x) is x.
        # If we have [2, 6, 9, 0, ...], GCD(2, 6)=2, GCD(2, 0)=2. So 0s extend the array without helping.
        # Shortest subarray calculation: effectively ignores 0s at ends.
        # [2, 6, 9]. GCD=1 (len 3). Ops = (3-1) + 7 = 9.
        ([2, 6, 9, 0, 0, 0, 0, 0], 9),
        # Case 7: [10, 10, 14, 14, 14, 14, 14, 14] (8 elements). Total GCD 2. Impossible.
        ([10, 10, 14, 14, 14, 14, 14, 14], -1),
        # Case 8: [2, 3, 2, 6, 9] padded -> [2, 3, 2, 6, 9, 0, 0, 0]. 
        # Shortest GCD 1: [2, 3] (len 2). Ops = (2-1)+7 = 8.
        ([2, 3, 2, 6, 9, 0, 0, 0], 8),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for arr, expected in test_cases:
        # Load inputs
        dut.a_0.value = arr[0]
        dut.a_1.value = arr[1]
        dut.a_2.value = arr[2]
        dut.a_3.value = arr[3]
        dut.a_4.value = arr[4]
        dut.a_5.value = arr[5]
        dut.a_6.value = arr[6]
        dut.a_7.value = arr[7]
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 250:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 250:
            raise TestFailure(f"Timeout for input {arr}")
        
        # Read result
        actual = int(dut.result.value)
        
        # Handle -1 representation (255)
        if expected == -1:
            if actual != 255:
                 raise TestFailure(f"Input {arr}: Expected -1 (255), got {actual}")
        else:
            if actual != expected:
                raise TestFailure(f"Input {arr}: Expected {expected}, got {actual}")
        
        passed += 1
        await RisingEdge(dut.clk) # Buffer between tests
    
    dut._log.info(f"{passed}/{total} tests passed")