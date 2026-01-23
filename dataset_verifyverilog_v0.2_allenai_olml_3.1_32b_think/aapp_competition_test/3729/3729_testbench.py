import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

# Python implementation of the correct logic to verify against
def python_logic(f, w, h):
    mod = 10**9 + 7
    
    # Precompute factorials up to 200000
    max_n = 200000
    fac = [1] * (max_n + 1)
    for i in range(1, max_n + 1):
        fac[i] = (i * fac[i-1]) % mod
    
    def inv(x):
        return pow(x, mod - 2, mod)
    
    def ncr(n, r):
        if r < 0 or r > n:
            return 0
        return (fac[n] * inv(fac[r]) % mod) * inv(fac[n-r]) % mod
    
    if w == 0:
        valid = 1
    else:
        valid = 0
        # k is number of wine stacks
        # Max k is limited by w//(h+1) and f+1
        max_k = min(w // (h + 1), f + 1)
        for k in range(1, max_k + 1):
            term1 = ncr(f + 1, k)
            term2 = ncr(w - k * h - 1, k - 1)
            valid = (valid + term1 * term2) % mod
    
    if f == 0 and w == 0:
        return 0 # Undefined case but inputs guarantee at least one item
    
    if w == 0:
        total = 1 # Only arrangement is all food
        if f == 0: return 0 # Should not happen based on constraints but safe
    else:
        total = ncr(f + w, w)
    
    if total == 0: return 0
    return (valid * inv(total)) % mod

@cocotb.test()
async def test_probability_calculator(dut):
    # Setup Clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.f.value = 0
    dut.w.value = 0
    dut.h.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        (1, 1, 1),
        (1, 2, 1),
        (6, 5, 7),
        (12, 12, 24),
        (20, 12, 32),
        (0, 1, 0),
        (0, 1, 1),
        (1, 0, 0),
        (1, 0, 1),
        (1, 1, 0),
        (100, 100, 100) # Scaled down version of large input
    ]
    
    passed = 0
    total = len(test_cases)
    
    for f, w, h in test_cases:
        dut.f.value = f
        dut.w.value = w
        dut.h.value = h
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 20000 # Cycles
        cycles = 0
        while dut.done.value == 0 and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
            
        if cycles >= timeout:
            print(f"TIMEOUT: f={f}, w={w}, h={h}")
            continue
            
        dut_result = int(dut.result.value)
        expected = python_logic(f, w, h)
        
        # Adjust expected for cases where python logic returns 0 for invalid inputs (if any)
        # Input constraint guarantees at least one item, so 0 0 0 is not in test cases
        
        if dut_result == expected:
            passed += 1
        else:
            print(f"FAILED: f={f}, w={w}, h={h}")
            print(f"  Expected: {expected}")
            print(f"  Got:      {dut_result}")
            
    print(f"
SUMMARY: {passed}/{total} tests passed")
    assert passed == total
