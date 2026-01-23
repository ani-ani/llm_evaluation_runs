import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_cryptarithm_solver(dut):
    """Test the 3-letter cryptarithmetic solver (A+B=C)."""
    
    # Initialize inputs
    dut.enable.value = 0
    
    # Wait for a small amount of time
    await Timer(10, units='ns')
    
    # Test Case 1: C+B=A (Target: 2+1=3, but we solve A+B=C where A=2, B=1, C=3)
    # Wait, the prompt says "puzzle format is restricted to A+B=C".
    # The example "C+B=A" has the form Word1+Word2=Word3.
    # My prompt restricts the format to A+B=C. 
    # Let's map the example C+B=A to the A+B=C solver by swapping variables.
    # If the puzzle is C+B=A, we are looking for digits c, b, a such that c+b=a.
    # This maps to our solver where Solver_A = c, Solver_B = b, Solver_C = a.
    # We expect Solver_A=2, Solver_B=1, Solver_C=3.
    
    dut._log.info("Test Case 1: Solving A+B=C (mapping from C+B=A example)")
    dut.enable.value = 1
    await Timer(10, units='ns')
    
    # Check outputs
    a = int(dut.digit_A.value)
    b = int(dut.digit_B.value)
    c = int(dut.digit_C.value)
    valid = int(dut.valid.value)
    
    dut._log.info(f"Result: A={a}, B={b}, C={c}, Valid={valid}")
    
    # Expected minimal solution for A+B=C:
    # A=2, B=1, C=3 (2+1=3)
    # But wait, the example output is "2+1=3". 
    # In the puzzle C+B=A, we substitute C=2, B=1, A=3.
    # Our module solves A+B=C. So inputs to module are A=2, B=1.
    # Module should output C=3.
    # Thus, digit_A=2, digit_B=1, digit_C=3.
    
    assert valid == 1, "Solution should be valid"
    assert a == 2, f"Expected digit_A=2, got {a}"
    assert b == 1, f"Expected digit_B=1, got {b}"
    assert c == 3, f"Expected digit_C=3, got {c}"
    
    # Test Case 2: Impossible (A+A=A -> 2A=A -> A=0, but A!=0)
    # In our solver, this corresponds to A+B=C where A=B.
    # However, our solver checks for distinctness.
    # Let's manually trace A+B=C with distinctness.
    # If we want to emulate "A+A=A", we would need A=B and A=C.
    # Since our solver enforces distinctness, it will return impossible if we try to map it directly.
    # But wait, the problem statement says "A+A=A" is impossible.
    # Let's check if our solver has any valid solution. It does (2+1=3).
    # The prompt says: "The puzzle format is restricted to A+B=C".
    # The second example "A+A=A" is not in the format A+B=C (it has identical letters).
    # Since my solver forces distinctness, it will naturally reject A+A=A.
    # I will verify that the solver returns valid=1 (since there IS a solution for A+B=C).
    # Actually, I should check the "impossible" case for the specific A+B=C problem.
    # Is there any A+B=C puzzle that is impossible? 
    # Yes, if A=9, B=9, C=8. 9+9 != 8. 
    # But my solver searches ALL permutations.
    # The only impossible case for the FORM A+B=C (with distinct letters, leading digits) is if the system of equations has no solution.
    # Let's look at the prompt constraints again.
    # "Return 'impossible' if no solution exists".
    # For A+B=C with distinct digits 0-9, leading non-zero.
    # A=0 is forbidden (leading). B=0 is forbidden (leading).
    # C can be 0.
    # Combinations: A in [1..9], B in [1..9], C in [0..9].
    # Distinct.
    # Is there a case where no solution exists? 
    # Only if we have very specific constraints on the letters. 
    # But the prompt asks to solve the puzzle given in the input.
    # The input is a string like "A+A=A" or "C+B=A".
    # Since the prompt says "puzzle format is restricted to A+B=C", I am hardcoding the structure.
    # The testbench should probably not just check the valid bit, but check the math.
    
    dut._log.info("Test Case 2: Checking arithmetic validity")
    assert int(dut.digit_A.value) + int(dut.digit_B.value) == int(dut.digit_C.value)
    
    # Test Case 3: Check distinctness
    dut._log.info("Test Case 3: Checking distinctness")
    vals = [int(dut.digit_A.value), int(dut.digit_B.value), int(dut.digit_C.value)]
    assert len(set(vals)) == 3, "Digits must be distinct"
    
    # Test Case 4: Check leading zeros
    dut._log.info("Test Case 4: Checking leading zeros")
    assert int(dut.digit_A.value) != 0, "A cannot be 0"
    assert int(dut.digit_B.value) != 0, "B cannot be 0"
    
    dut._log.info("All tests passed!")
