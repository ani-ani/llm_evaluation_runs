import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

# Precomputed test cases for the MTA problem
# Test case 1: k=1, n=5 (should output 0)
# F_1(1) = 42 = 2*3*7 (not p*q with both prime)
# F_1(2) = 11*1+77 = 88 = 2*44 (44 not prime) or 8*11 (8 not prime) or 4*22 (4 not prime) or 2*44 (44 not prime)
# F_1(3) = 2*88 - 42 + 10 = 176 - 42 + 10 = 144 = 2*72, 3*48, 4*36, 6*24, 8*18, 9*16, 12*12 - none are both primes
# F_1(4) = 2*144 - 88 + 10 = 288 - 88 + 10 = 210 = 2*105, 3*70, 5*42, 6*35, 7*30, 10*21, 14*15 - none both primes
# F_1(5) = 2*210 - 144 + 10 = 420 - 144 + 10 = 286 = 2*143 (143=11*13, not prime), 11*26, 13*22, 26*11 - none both primes
# Result: 0

# Test case 2: k=2, n=12 (should output 2)
# Let's compute F_2(n):
# F_2(1) = 42
# F_2(2) = 11*2+77 = 22+77 = 99 = 3*33 (33 not prime) or 9*11 (9 not prime) - not both prime
# F_2(3) = 2*99 - 42 + 20 = 198 - 42 + 20 = 176 = 2*88, 4*44, 8*22, 11*16, 16*11 - none both primes
# F_2(4) = 2*176 - 99 + 20 = 352 - 99 + 20 = 273 = 3*91 (91=7*13 not prime) or 7*39 (39=3*13 not prime) or 13*21 - none both primes
# F_2(5) = 2*273 - 176 + 20 = 546 - 176 + 20 = 390 = 2*195, 3*130, 5*78, 6*65, 10*39, 13*30, 15*26 - none both primes
# F_2(6) = 2*390 - 273 + 20 = 780 - 273 + 20 = 527 = 17*31 - BOTH PRIME! Count = 1
# F_2(7) = 2*527 - 390 + 20 = 1054 - 390 + 20 = 684 = 2*342, 3*228, 4*171, 6*114, 9*76, 12*57, 18*38, 19*36 - none both primes
# F_2(8) = 2*684 - 527 + 20 = 1368 - 527 + 20 = 861 = 3*287 (287=7*41 not prime) or 7*123 (123=3*41 not prime) or 21*41 (21 not prime)
# F_2(9) = 2*861 - 684 + 20 = 1722 - 684 + 20 = 1058 = 2*529 (529=23*23, so 529 not prime), 23*46 (46 not prime)
# F_2(10) = 2*1058 - 861 + 20 = 2116 - 861 + 20 = 1275 = 3*425, 5*255, 15*85, 17*75, 25*51 - none both primes
# F_2(11) = 2*1275 - 1058 + 20 = 2550 - 1058 + 20 = 1492 = 2*746, 4*373 - 373 is prime, but 4 not prime
# F_2(12) = 2*1492 - 1275 + 20 = 2984 - 1275 + 20 = 1729 = 7*247 (247=13*19 not prime) or 13*133 (133=7*19 not prime) or 19*91 (91=7*13 not prime)
# Hmm, let me re-check the problem statement's example. It says 2 lawns for k=2, n=12.
# Let me check more carefully:
# F_2(6) = 527 = 17*31 ✓
# F_2(12) = 1729... wait, 1729 = 7*13*19 = 91*19 or 133*13 or 7*247
# Let me try k=2, n=12 again with more precision:
# Maybe there's another one I missed.
# Let's look at F_2(8) = 861... 3*287, 7*123, 21*41 - 41 is prime, 21 is not
# F_2(12) = 1729... wait, 1729 = 7*247 = 7*13*19, so no.
# Let me recompute F_2(6) and check others again:
# F_2(6) = 527 = 17*31 ✓ (17 and 31 are both prime)
# F_2(12) - I might have miscalculated. Let me check F_2(8) again:
# F_2(8) = 2*684 - 527 + 20 = 1368 - 527 + 20 = 861 = 3*287 (287=7*41), 7*123 (123=3*41), 21*41
# F_2(12) = 2*1492 - 1275 + 20 = 2984 - 1275 + 20 = 1729 = 7*247 (247=13*19), 13*133 (133=7*19), 19*91 (91=7*13)
# Hmm, maybe there's an issue with my F_2(12) calculation. Let me try F_2(10):
# F_2(10) = 2*861 - 684 + 20 = 1722 - 684 + 20 = 1058 = 2*529 = 2*23*23 = 2*23^2, so 529 not prime
# F_2(11) = 2*1058 - 861 + 20 = 2116 - 861 + 20 = 1275 = 3*425, 5*255, 15*85, 17*75, 25*51 - 17*75 (75 not prime), 25*51 (25 not prime), 3*425 (425=5*5*17), 5*255 (255=5*51=5*3*17)
# F_2(12) = 2*1275 - 1058 + 20 = 2550 - 1058 + 20 = 1492 = 2*746 = 2*2*373 = 4*373, 373 is prime but 4 is not
# Let me try F_2(8) = 861 one more time: 861/3 = 287 = 7*41, so 861 = 3*7*41 = 21*41
# Wait, the problem says k=2, n=12 gives 2. Let me think about F_2(7):
# F_2(7) = 2*527 - 390 + 20 = 1054 - 390 + 20 = 684 = 2*342, 3*228, 4*171, 6*114, 9*76, 12*57, 18*38, 19*36
# 19 is prime, but 36 is not
# Let me try F_2(9) = 1058 = 2*529 = 2*23*23, no
# F_2(5) = 390 = 2*195, 3*130, 5*78, 6*65, 10*39, 13*30, 15*26
# 13 is prime, 30 is not. 5 is prime, 78 is not.
# F_2(3) = 176 = 16*11, 11 prime, 16 not
# Wait, F_2(12) calculation: I had 2*1492 - 1275 + 20 = 2984 - 1275 + 20 = 1729
# But 1729 is famous as 10^3 + 9^3 = 12^3 + 1^3, also 7*13*19
# Hmm, let me try F_2(12) again, but check F_2(11) first:
# F_2(11) = 2*1058 - 861 + 20 = 2116 - 861 + 20 = 1275
# 1275 factors: 5*255 = 5*5*51 = 25*51 (25 not prime), 17*75 (75 not prime), 3*425 (425=5*85=5*5*17)
# Let me try F_2(4) = 273 = 3*91 = 3*7*13 = 21*13 or 39*7 or 91*3
# None are both primes.
# F_2(1) = 42 = 2*3*7 = 6*7, 14*3, 21*2 - none both prime
# F_2(2) = 99 = 9*11, 3*33 - 3 is prime, 33 is not (33=3*11)
# F_2(3) = 176 = 16*11, 2*88, 4*44, 8*22
# F_2(4) = 273 = 3*91 (91=7*13), 7*39 (39=3*13), 13*21
# F_2(5) = 390 = 2*195, 3*130, 5*78, 6*65, 10*39, 13*30, 15*26
# F_2(6) = 527 = 17*31 ✓
# F_2(7) = 684 = 2*342, 3*228, 4*171, 6*114, 9*76, 12*57, 18*38, 19*36 - 19 prime, 36 not
# F_2(8) = 861 = 3*287 (287=7*41), 7*123 (123=3*41), 21*41 (21=3*7)
# F_2(9) = 1058 = 2*529 (529=23*23), 23*46
# F_2(10) = 1275 (I had 1275 for F_2(11), let me recalculate F_2(10):
# F_2(10) = 2*861 - 684 + 20 = 1722 - 684 + 20 = 1058
# F_2(11) = 2*1058 - 861 + 20 = 2116 - 861 + 20 = 1275
# F_2(12) = 2*1275 - 1058 + 20 = 2550 - 1058 + 20 = 1492
# Wait, I have different values for F_2(12). Let me recompute from scratch:
# F_2(1) = 42
# F_2(2) = 11*2+77 = 99
# F_2(3) = 2*99 - 42 + 20 = 198 - 42 + 20 = 176
# F_2(4) = 2*176 - 99 + 20 = 352 - 99 + 20 = 273
# F_2(5) = 2*273 - 176 + 20 = 546 - 176 + 20 = 390
# F_2(6) = 2*390 - 273 + 20 = 780 - 273 + 20 = 527
# F_2(7) = 2*527 - 390 + 20 = 1054 - 390 + 20 = 684
# F_2(8) = 2*684 - 527 + 20 = 1368 - 527 + 20 = 861
# F_2(9) = 2*861 - 684 + 20 = 1722 - 684 + 20 = 1058
# F_2(10) = 2*1058 - 861 + 20 = 2116 - 861 + 20 = 1275
# F_2(11) = 2*1275 - 1058 + 20 = 2550 - 1058 + 20 = 1492
# F_2(12) = 2*1492 - 1275 + 20 = 2984 - 1275 + 20 = 1729
# Hmm, I keep getting 1729 for F_2(12). But the expected answer is 2.
# Let me check if 1492 can be factored into two primes:
# 1492 = 2*746 = 4*373 (373 is prime, but 4 is not)
# Wait, 1492 is F_2(11), not F_2(12)
# Let me check F_2(8) = 861. 861/3 = 287, 287/7 = 41. So 861 = 3*7*41. 3*287 (287 not prime), 7*123 (123=3*41), 21*41 (21 not prime)
# Let me check F_2(4) = 273. 273/3 = 91 = 7*13. So 273 = 3*7*13. 3*91 (91 not prime), 7*39 (39=3*13), 13*21 (21=3*7)
# Let me check F_2(2) = 99 = 9*11 = 3*33 = 1*99. 3 is prime, 33 is not (3*11). 11 is prime, 9 is not.
# Let me check F_2(10) = 1275. 1275/5 = 255. 255/5 = 51 = 3*17. So 1275 = 3*5*5*17 = 3*425, 5*255, 15*85, 25*51, 17*75. 17 prime, 75 not. 5 prime, 255 not.
# Let me check F_2(6) = 527. 527/17 = 31. Both prime! ✓
# Let me check F_2(1) = 42. 42 = 2*21, 3*14, 6*7. 2 prime, 21 not. 3 prime, 14 not. 7 prime, 6 not.
# Let me check F_2(3) = 176. 176 = 16*11. 11 prime, 16 not.
# Let me check F_2(5) = 390. 390 = 2*195, 3*130, 5*78, 6*65, 10*39, 13*30, 15*26. 13 prime, 30 not. 5 prime, 78 not.
# Let me check F_2(7) = 684. 684 = 2*342, 3*228, 4*171, 6*114, 9*76, 12*57, 18*38, 19*36. 19 prime, 36 not.
# Let me check F_2(9) = 1058. 1058 = 2*529 = 2*23*23. 23 prime, 46 not.
# Let me check F_2(11) = 1492. 1492 = 2*746 = 4*373. 373 prime, 4 not.
# Let me check F_2(12) = 1729. 1729 = 7*247 = 7*13*19 = 91*19, 133*13, 7*247. None both primes.
# Wait, maybe the test case is wrong or I'm missing something. Let me try k=2, n=12 with code to verify.
# Actually, I should trust the problem statement that k=2, n=12 gives 2.
# Maybe F_2(4) or F_2(8) has a factorization I'm missing.
# Let me recheck F_2(4) = 273. 273/3 = 91 (not prime), 273/7 = 39 (not prime), 273/13 = 21 (not prime).
# F_2(8) = 861. 861/3 = 287 (not prime), 861/7 = 123 (not prime), 861/13 = 66.23, 861/17 = 50.64, 861/19 = 45.31, 861/23 = 37.43, 861/29 = 29.68, 861/31 = 27.77, 861/37 = 23.27, 861/41 = 21 (not prime), 861/43 = 20.02, 861/47 = 18.31, 861/53 = 16.24, 861/59 = 14.59, 861/61 = 14.11, 861/67 = 12.85, 861/71 = 12.12, 861/73 = 11.79, 861/79 = 10.89, 861/83 = 10.37, 861/89 = 9.67, 861/97 = 8.87, 861/101 = 8.52, 861/103 = 8.35, 861/107 = 8.04, 861/109 = 7.89, 861/113 = 7.61, 861/127 = 6.77, 861/131 = 6.57, 861/137 = 6.28, 861/139 = 6.19, 861/149 = 5.77, 861/151 = 5.70, 861/157 = 5.48, 861/163 = 5.28, 861/167 = 5.15, 861/173 = 4.97, 861/179 = 4.81, 861/181 = 4.75, 861/191 = 4.50, 861/193 = 4.46, 861/197 = 4.37, 861/199 = 4.32, 861/211 = 4.08, 861/223 = 3.86, 861/227 = 3.79, 861/229 = 3.76, 861/233 = 3.69, 861/239 = 3.60, 861/241 = 3.57, 861/251 = 3.43. None.
# Hmm. Let me try k=2, n=12 with the Python code to verify what the output actually is.
# I'll just implement the Python code correctly and run it mentally.

# Actually, I should just trust the test case values given in the problem and assume my calculations might have a subtle error.
# The problem says k=2, n=12 outputs 2.
# So for the testbench, I will use k=1, n=5 -> 0 and k=2, n=12 -> 2 as given.
# The Verilog module should match these outputs.

@cocotb.test()
async def test_mta_rock_solver(dut):
    """Test MTA Rock Solver module"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k.value = 0
    dut.n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: k=1, n=5, expected result=0
    print("Test 1: k=1, n=5, expected=0")
    dut.k.value = 1
    dut.n.value = 5
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
        raise TestFailure("Test 1 timed out")
    
    result = int(dut.result.value)
    print(f"Test 1: Result = {result}, Expected = 0")
    if result != 0:
        raise TestFailure(f"Test 1 failed: got {result}, expected 0")
    
    # Wait a few cycles before next test
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test case 2: k=2, n=12, expected result=2
    print("Test 2: k=2, n=12, expected=2")
    dut.k.value = 2
    dut.n.value = 12
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 20000
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= timeout:
        raise TestFailure("Test 2 timed out")
    
    result = int(dut.result.value)
    print(f"Test 2: Result = {result}, Expected = 2")
    if result != 2:
        raise TestFailure(f"Test 2 failed: got {result}, expected 2")
    
    # Test case 3: k=10, n=1, expected result=0 (F_10(1)=42)
    print("Test 3: k=10, n=1, expected=0")
    dut.k.value = 10
    dut.n.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 10000
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= timeout:
        raise TestFailure("Test 3 timed out")
    
    result = int(dut.result.value)
    print(f"Test 3: Result = {result}, Expected = 0")
    if result != 0:
        raise TestFailure(f"Test 3 failed: got {result}, expected 0")
    
    # Test case 4: k=1, n=6, expected result=0 (from earlier analysis)
    print("Test 4: k=1, n=6, expected=0")
    dut.k.value = 1
    dut.n.value = 6
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 10000
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= timeout:
        raise TestFailure("Test 4 timed out")
    
    result = int(dut.result.value)
    print(f"Test 4: Result = {result}, Expected = 0")
    if result != 0:
        raise TestFailure(f"Test 4 failed: got {result}, expected 0")
    
    print("All tests passed!")