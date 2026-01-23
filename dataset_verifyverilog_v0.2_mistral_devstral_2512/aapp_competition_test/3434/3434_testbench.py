import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

async def compute_probability_reference(n, m, d, my_health, opp_health):
    """Reference Python implementation for verification"""
    from functools import lru_cache
    
    # Convert to tuple for hashing
    my_t = tuple(my_health[:n])
    opp_t = tuple(opp_health[:m])
    
    @lru_cache(maxsize=None)
    def solve(my_h, opp_h, dmg):
        if dmg == 0:
            return 1.0 if len(opp_h) == 0 else 0.0
        
        total_minions = len(my_h) + len(opp_h)
        if total_minions == 0:
            return 1.0  # No minions left, opponent is eliminated
        
        prob = 0.0
        # Try hitting each of my minions
        for i in range(len(my_h)):
            new_health = list(my_h)
            new_health[i] -= 1
            if new_health[i] <= 0:
                new_my = tuple(new_health[:i] + new_health[i+1:])
            else:
                new_my = tuple(new_health)
            prob += solve(new_my, opp_h, dmg-1)
        
        # Try hitting each opponent minion
        for i in range(len(opp_h)):
            new_health = list(opp_h)
            new_health[i] -= 1
            if new_health[i] <= 0:
                new_opp = tuple(new_health[:i] + new_health[i+1:])
            else:
                new_opp = tuple(new_health)
            prob += solve(my_h, new_opp, dmg-1)
        
        return prob / total_minions
    
    result = solve(my_t, opp_t, d)
    return result

@cocotb.test()
async def test_explosion_probability(dut):
    """Test explosion probability calculation"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.m.value = 0
    dut.damage.value = 0
    for i in range(5):
        dut.my_minions_health[i].value = 0
        dut.opp_minions_health[i].value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # (n, m, d, my_health, opp_health, expected)
        (1, 2, 2, [2], [1, 1], 0.3333333333),
        (2, 3, 12, [3, 2], [4, 2, 3], 0.1377380946),
        (1, 1, 1, [2], [1], 1.0),
        (1, 1, 2, [2], [2], 0.5),
        (2, 1, 3, [1, 1], [2], 0.75),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, (n, m, d, my_h, opp_h, expected) in enumerate(test_cases):
        print(f"
Test {idx+1}: n={n}, m={m}, d={d}")
        print(f"My health: {my_h}, Opp health: {opp_h}")
        print(f"Expected: {expected:.10f}")
        
        # Compute reference
        reference = await compute_probability_reference(n, m, d, my_h, opp_h)
        print(f"Reference: {reference:.10f}")
        
        # Load inputs
        dut.n.value = n
        dut.m.value = m
        dut.damage.value = d
        for i in range(5):
            dut.my_minions_health[i].value = my_h[i] if i < len(my_h) else 0
            dut.opp_minions_health[i].value = opp_h[i] if i < len(opp_h) else 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 10000
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            print(f"  TIMEOUT after {timeout} cycles")
            continue
        
        # Read result
        result_fp = int(dut.probability.value)
        result_float = result_fp / 65536.0
        print(f"Result: {result_float:.10f} (FP: 0x{result_fp:08X})")
        
        # Check with tolerance
        tolerance = 0.001
        if abs(result_float - reference) < tolerance:
            print("  PASS")
            passed += 1
        else:
            print(f"  FAIL: diff = {abs(result_float - reference):.10f}")
        
        await RisingEdge(dut.clk)
        await Timer(100, units="ns")
    
    print(f"
{passed}/{total} tests passed")
    if passed < total:
        raise TestFailure(f"Only {passed} out of {total} tests passed")
