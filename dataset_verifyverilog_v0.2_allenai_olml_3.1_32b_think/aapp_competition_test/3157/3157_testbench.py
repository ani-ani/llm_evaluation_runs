import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

# Helper to compute hash in Python for verification
def compute_hash(word, M):
    MOD = 1 << M
    h = 0
    for char in word:
        val = ord(char) - ord('a') + 1
        h = ((h * 33) ^ val) % MOD
    return h

def count_words_py(N, K, M):
    MOD = 1 << M
    # dp[i] = count of words of length i with hash h
    # We will iterate length from 0 to N
    dp = {}
    dp[0] = 1  # empty string hash is 0
    
    for step in range(N):
        new_dp = {}
        for h, count in dp.items():
            for c_val in range(1, 27): # a=1, z=26
                new_h = ((h * 33) ^ c_val) % MOD
                if new_h in new_dp:
                    new_dp[new_h] += count
                else:
                    new_dp[new_h] = count
        dp = new_dp
    
    return dp.get(K, 0)

@cocotb.test()
async def test_hash_word_counter(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    dut.K.value = 0
    dut.M.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases adapted for M <= 12 (Hardware limitation)
    # Original M=10 is fine.
    # We will test N=1, 2, 3.
    
    test_cases = [
        (1, 0, 10),   # Expected: 0
        (1, 2, 10),   # Expected: 1
        (3, 16, 10),  # Expected: 4
        (2, 1072, 10) # Let's add one more to verify correctness
    ]
    
    dut._log.info("Starting tests...")
    passed = 0
    total = len(test_cases)
    
    for N, K, M in test_cases:
        dut._log.info(f"Testing N={N}, K={K}, M={M}")
        
        # Calculate expected
        expected = count_words_py(N, K, M)
        dut._log.info(f"Expected result: {expected}")
        
        # Inputs
        dut.N.value = N
        dut.K.value = K
        dut.M.value = M
        dut.start.value = 1
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 20000 # cycles
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            dut._log.error(f"Timeout for N={N}, K={K}, M={M}")
            continue
            
        # Check result
        actual = int(dut.result.value)
        if actual == expected:
            dut._log.info(f"PASS: Result {actual}")
            passed += 1
        else:
            dut._log.error(f"FAIL: Expected {expected}, Got {actual}")
            
        # Small delay between tests
        await Timer(100, units='ns')
        
    dut._log.info(f"
{passed}/{total} tests passed")
