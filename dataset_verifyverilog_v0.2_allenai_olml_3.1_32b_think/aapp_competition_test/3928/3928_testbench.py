import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

def compute_min_cost(s, a, b):
    """Reference Python implementation for verification"""
    n = len(s)
    dp = [0] * (n + 1)
    dp[0] = 0
    
    for i in range(1, n + 1):
        dp[i] = dp[i-1] + a  # Single character cost
        
        # Check for substring match
        for j in range(i):
            # Check if s[j:i] is substring of s[0:j]
            substr = s[j:i]
            found = False
            for k in range(j):
                # Check all substrings ending at k in s[0:j]
                for l in range(1, k+2):
                    if s[k-l+1:k+1] == substr:
                        found = True
                        break
                if found:
                    break
            if found:
                dp[i] = min(dp[i], dp[j] + b)
    
    return dp[n]

@cocotb.test()
async def test_string_compressor(dut):
    """Test string compressor with multiple test cases"""
    
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.a_cost.value = 0
    dut.b_cost.value = 0
    dut.str_len.value = 0
    
    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Wait for reset
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (string, a, b, expected_cost)
    test_cases = [
        ("aba", 3, 1, 7),
        ("abcd", 1, 1, 4),
        ("aaaa", 10, 1, 12),
        ("a", 5, 2, 5),
        ("ab", 2, 10, 4),
        ("aa", 3, 1, 4),  # 'a' (3) + 'a' (1) = 4
    ]
    
    passed = 0
    total = len(test_cases)
    
    for string, a_val, b_val, expected in test_cases:
        print(f"
Testing: s='{string}', a={a_val}, b={b_val}, expected={expected}")
        
        # Load parameters
        dut.a_cost.value = a_val
        dut.b_cost.value = b_val
        dut.str_len.value = len(string)
        await RisingEdge(dut.clk)
        
        # Load characters one by one
        for i, char in enumerate(string):
            dut.char_in.value = ord(char)
            dut.start.value = 1 if i == 0 else 0
            await RisingEdge(dut.clk)
        
        # Wait for computation to complete (done signal)
        # Need to wait for enough cycles for the state machine
        max_wait = 500
        for _ in range(max_wait):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        # Read result
        result = int(dut.min_cost.value)
        print(f"Result: {result}, Expected: {expected}")
        
        if result == expected:
            passed += 1
            print("PASS")
        else:
            print(f"FAIL: Got {result}, expected {expected}")
    
    print(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed}/{total} tests passed"
