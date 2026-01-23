import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

async def compute_expected(n, a):
    """Compute expected result using Python logic"""
    if sum(a) == 1:
        return -1, False
    
    # Find prime factors
    su = sum(a)
    primes = []
    temp = su
    i = 2
    while i * i <= temp:
        while temp % i == 0:
            primes.append(i)
            temp //= i
        i += 1
    if temp > 1:
        primes.append(temp)
    primes = sorted(set(primes))
    
    if not primes:
        return -1, False
    
    ans = 10**18
    for p in primes:
        an = 0
        half = p >> 1
        cnt = 0
        valid = True
        for a_val in a:
            a_mod = a_val % p
            cnt += a_mod
            if cnt <= half:
                an += cnt
            else:
                if cnt < p:
                    an += p - cnt
                else:
                    cnt -= p
                    if cnt <= half:
                        an += cnt
                    else:
                        an += p - cnt
            if ans <= an:
                valid = False
                break
        if valid:
            ans = min(ans, an)
    
    if ans == 10**18:
        return -1, False
    return ans, True

@cocotb.test()
async def test_chocolate_distribution(dut):
    """Test chocolate distribution module with multiple test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.sum_total.value = 0
    for i in range(16):
        dut.a[i].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ([4, 8, 5], 9),      # 4+8+5=17, primes={17}, cost=9
        ([3, 10, 2, 1, 5], 2), # 21, primes={3,7}, cost=2 (k=3)
        ([0, 5, 15, 10], 0),   # 30, already divisible by 5
        ([1], -1),            # sum=1, no solution
        ([0, 0, 17], 0),      # 17, already divisible
        ([0, 0, 1], -1),      # sum=1, no solution
        ([1, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1], 6), # sum=7, primes={7}, cost=6
    ]
    
    passed = 0
    total = len(test_cases)
    
    for a_list, expected in test_cases:
        n_val = len(a_list)
        sum_val = sum(a_list)
        
        # Load inputs
        dut.n.value = n_val
        dut.sum_total.value = sum_val
        for i in range(16):
            dut.a[i].value = a_list[i] if i < n_val else 0
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 200
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Timeout waiting for done signal for test case {a_list}")
        
        # Check result
        actual = int(dut.result.value)
        no_sol = int(dut.no_solution.value)
        
        if expected == -1:
            if no_sol != 1:
                print(f"FAIL: Input {a_list}. Expected no_solution=1, got {no_sol}")
            else:
                passed += 1
                print(f"PASS: Input {a_list}. Correctly identified no solution")
        else:
            if no_sol == 1:
                print(f"FAIL: Input {a_list}. Expected solution {expected}, got no_solution=1")
            elif actual != expected:
                print(f"FAIL: Input {a_list}. Expected {expected}, got {actual}")
            else:
                passed += 1
                print(f"PASS: Input {a_list}. Got {actual}")
    
    print(f"
Summary: {passed}/{total} tests passed")
    if passed < total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")
