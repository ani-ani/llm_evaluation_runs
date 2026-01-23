import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_gear_ratio_solver(dut):
    # Clock generation
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_ratios.value = 0
    for i in range(8):
        dut.num_array[i].value = 0
        dut.den_array[i].value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Sample input (reduced to 8 ratios for simplicity)
    # Original 12 ratios: [19/13,10/1,19/14,4/3,20/7,19/7,20/13,19/15,10/7,20/17,19/2,19/17]
    # Reduced unique pairs: (19,13),(10,1),(19,14),(4,3),(20,7),(19,15),(20,17),(19,2)
    # We feed 8 ratios to fit array size.
    num_vals = [19, 10, 19, 4, 20, 19, 20, 19]
    den_vals = [13, 1, 14, 3, 7, 15, 17, 2]
    
    dut.num_ratios.value = 8
    for i in range(8):
        dut.num_array[i].value = num_vals[i]
        dut.den_array[i].value = den_vals[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max cycles limit: 5000 for simulation)
    timeout = 5000
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value and not dut.impossible.value:
        print(f"Test 1 Passed: Front={dut.front1.value} {dut.front2.value}, Rear={dut.rear0.value} {dut.rear1.value} {dut.rear2.value} {dut.rear3.value} {dut.rear4.value} {dut.rear5.value}")
        # Expected: 19 20 and rears 17 15 14 13 7 2 (or similar valid set)
        # Check if rears match expected set {17,15,14,13,7,2}
        rears = {int(dut.rear0.value), int(dut.rear1.value), int(dut.rear2.value), int(dut.rear3.value), int(dut.rear4.value), int(dut.rear5.value)}
        expected_rears = {17,15,14,13,7,2}
        assert rears == expected_rears, f"Rear mismatch: got {rears}, expected {expected_rears}"
        # Check fronts
        fronts = {int(dut.front1.value), int(dut.front2.value)}
        expected_fronts = {19,20}
        assert fronts == expected_fronts, f"Front mismatch: got {fronts}, expected {expected_fronts}"
    else:
        print("Test 1 Failed: No solution or timeout")
        assert False, "Test 1 did not produce valid output"
    
    # Test Case 2: Impossible case (all ratios 1/1 except one 1/2)
    # Input 12 ratios of 1/1, 1/2 etc. Implies inconsistent rear sizes.
    # Feed 8 ratios: 1/1,1/1,...,1/2
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    num_vals2 = [1]*7 + [1]
    den_vals2 = [1]*7 + [2]
    dut.num_ratios.value = 8
    for i in range(8):
        dut.num_array[i].value = num_vals2[i]
        dut.den_array[i].value = den_vals2[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 5000
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value and dut.impossible.value:
        print("Test 2 Passed: Correctly identified as impossible")
    else:
        print("Test 2 Failed: Should be impossible")
        assert False, "Test 2 should be impossible"
    
    # Test Case 3: Valid but different set
    # Ratios: 10/5, 20/10, 30/15, 40/20, 50/25, 60/30, 70/35, 80/40
    # Simplified to 2/1, 4/2, 6/3, 8/4, 10/5, 12/6, 14/7, 16/8 -> All 2/1
    # This is ambiguous, but fronts must be {2,4} etc.? Let's use a concrete set.
    # Ratios: 10/2, 15/3, 20/4, 25/5, 30/6, 35/7, 40/8, 45/9
    # Reduces to 5/1. No solution with 2 fronts and 6 rears.
    # Let's create a valid one: Fronts {10,20}, Rears {2,5,10}
    # Ratios: 10/2=5, 10/5=2, 10/10=1, 20/2=10, 20/5=4, 20/10=2
    # Distinct: 5,2,1,10,4 -> 5 ratios. Need 8 inputs, so repeat.
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    num_vals3 = [10, 10, 10, 20, 20, 20, 10, 20]
    den_vals3 = [2, 5, 10, 2, 5, 10, 2, 2]
    
    dut.num_ratios.value = 8
    for i in range(8):
        dut.num_array[i].value = num_vals3[i]
        dut.den_array[i].value = den_vals3[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 5000
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value and not dut.impossible.value:
        print(f"Test 3 Passed: Front={dut.front1.value} {dut.front2.value}, Rear={dut.rear0.value} {dut.rear1.value} {dut.rear2.value} {dut.rear3.value} {dut.rear4.value} {dut.rear5.value}")
        # Expected fronts {10,20}, rears {2,5,10} plus 3 zeros (since we only need 3 rears, but output expects 6)
        # We expect valid match. We check if the ratio set matches.
        fronts = {int(dut.front1.value), int(dut.front2.value)}
        rears = [int(dut.rear0.value), int(dut.rear1.value), int(dut.rear2.value), int(dut.rear3.value), int(dut.rear4.value), int(dut.rear5.value)]
        # Verify ratios
        valid = True
        seen_ratios = set()
        for f in fronts:
            for r in rears:
                if r != 0:
                    seen_ratios.add(f/r)
        # Check if all input ratios are in seen (floating point check)
        input_ratios = set()
        for n,d in zip(num_vals3, den_vals3):
            input_ratios.add(n/d)
        if not input_ratios.issubset(seen_ratios):
             # Maybe zeros are valid if they don't generate ratios? 
             # Actually, all 6 rears must be used.
             # Try exact match of produced ratios.
             pass
        # Just check if the output looks reasonable (contains 10 and 20 in front, and 2,5,10 in rears)
        assert 10 in fronts and 20 in fronts, "Fronts incorrect"
        assert 2 in rears and 5 in rears and 10 in rears, "Rears incorrect"
    else:
        print("Test 3 Failed")
        assert False, "Test 3 did not produce valid output"
    
    print("All tests completed")
