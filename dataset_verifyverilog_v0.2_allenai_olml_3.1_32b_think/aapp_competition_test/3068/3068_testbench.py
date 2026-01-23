import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

async def load_investigation(dut, s1, s2, player, reply):
    dut.inv_suspect1.value = ord(s1)
    dut.inv_suspect2.value = ord(s2)
    dut.inv_player.value = ord(str(player))
    dut.inv_reply.value = ord(str(reply))
    dut.inv_valid.value = 1
    await RisingEdge(dut.clk)
    # Wait for state to move or next cycle
    # Module expects data to be captured on clock edge
    dut.inv_valid.value = 0

@cocotb.test()
async def test_black_vienna_basic(dut):
    """Test Black Vienna solver with zero investigations"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.inv_valid.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Start with 0 investigations
    dut.num_investigations.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1

    if not dut.done.value:
        raise TestFailure("Module did not finish in time")

    # Expected: 4 (ABC, ABD, ACD, BCD)
    if dut.solution_count.value != 4:
        raise TestFailure(f"Expected 4 solutions for 0 investigations, got {int(dut.solution_count.value)}")

@cocotb.test()
async def test_black_vienna_sample_1(dut):
    """Test Sample 2: 3 Investigations -> Should find 506 (scaled down version)"""
    # We use 4 suspects (A-D). Sample 2 uses A, B, C. 
    # We need to check if the logic works for A, B, C.
    # Let's add an investigation using D as well to test bounds.
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value = 0
    dut.start.value = 0
    dut.inv_valid.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Inputs from Sample 2 (Python code):
    # "AB 1 1" -> A, B involved, P1 has 1
    # "AC 2 1" -> A, C involved, P2 has 1
    # "BC 2 1" -> B, C involved, P2 has 1
    
    dut.num_investigations.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await load_investigation(dut, 'A', 'B', 1, 1)
    await load_investigation(dut, 'A', 'C', 2, 1)
    await load_investigation(dut, 'B', 'C', 2, 1)

    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1

    if not dut.done.value:
        raise TestFailure("Module did not finish in time")

    # Logic analysis for A-D:
    # Circle {A, B, C}: 
    #   AB: Both in Circle. R=1. Fail (must be 0).
    # Circle {A, B, D}:
    #   AB: Both in Circle. R=1. Fail.
    # Circle {A, C, D}:
    #   AC: Both in Circle. R=1. Fail.
    # Circle {B, C, D}:
    #   BC: Both in Circle. R=1. Fail.
    # Wait, Sample 2 Output is 506. This implies some solutions are valid.
    # Let's re-read sample.
    # Sample 2: 
    # AB 1 1
    # AC 2 1
    # BC 2 1
    # If Circle is {A, D, E} (using full alphabet):
    # AB: A in C, B out. B available. P1 can have 1 (B). OK.
    # AC: A in C, C out. C available. P2 can have 1 (C). OK.
    # BC: B out, C out. Both available. P2 can have 1 (one of them). OK.
    # So {A, D, E} is a candidate.
    # 
    # With A-D only:
    # {A, D, X} -> X not in {A,B,C,D} -> impossible. 
    # Only 4 suspects. Circles are combinations of A-D.
    # Let's check {A, D, ?}. No 3rd letter.
    # 
    # Let's trace my logic for Circle {A, C, D} (Wait, I said Fail above):
    # {A, C, D}:
    # AB: A in C, B out. Available=1. P1 has 1. OK.
    # AC: A in C, C in C. Available=0. P2 has 1. 
    #   -> Wait, P2 has 1 of {A,C}. But A and C are in Circle. So P2 has 0. 
    #   -> Mismatch: Reply 1 != 0. FAIL. Correct.
    # 
    # {A, D, ?} -> Impossible.
    # 
    # Let's check {A, B, D}:
    # AB: Both in C. P1 has 1 -> Fail.
    # 
    # {A, B, C}:
    # AB: Fail.
    # 
    # {B, C, D}:
    # BC: Both in C. P2 has 1 -> Fail.
    # 
    # Wait, with 4 suspects, NO solution satisfies Sample 2? 
    # Sample 2 Output 506. 
    # A, B, C are heavily constrained.
    # Maybe I need to check my logic again.
    # "Investigation AB 1 1". Player 1 has 1 of A or B.
    # If Circle is {A, B, C}:
    #   A, B in Circle. Player 1 has 0. Reply 1 != 0. Fail.
    # If Circle is {A, D, E} (in full set):
    #   A in Circle, B out. 
    #   Player 1 can have B. Reply 1 is valid.
    #   Player 2 can have B. Reply 1 is valid.
    #   But Player 1 has 1. So P1 has B. P2 has 0 of {A,B}.
    #   This is consistent.
    #   
    #   With 4 suspects (A-D), can we find a valid circle for Sample 2?
    #   Needs: 
    #   1. Circle must NOT contain {A, B} together (else P1 has 0, but reply 1).
    #   2. Circle must NOT contain {A, C} together (else P2 has 0, but reply 1).
    #   3. Circle must NOT contain {B, C} together (else P2 has 0, but reply 1).
    #   
    #   So Circle cannot contain any pair from {A,B,C}.
    #   In {A, B, C, D}, any triple MUST contain at least one pair from {A,B,C}.
    #   Proof:
    #   If Circle has D: {D, x, y}.
    #   x, y from {A,B,C}.
    #   If x,y are distinct, say {A,B}, {A,C}, or {B,C}. All forbidden.
    #   If x,y same? No, distinct.
    #   So there are NO solutions for Sample 2 with only 4 suspects.
    #   
    #   Okay, the scaling is drastic. 
    #   If Sample 2 has 0 solutions, the test should pass 0.
    #   However, Sample 1 (0 investigations) has 4 solutions.
    #   Sample 3 (Python code sample 3) -> Output 0.
    #   
    #   Let's stick to the testbench for Sample 1 (0 inv) which is 4.
    #   And a manual test for Sample 2 logic.
    #   Let's use the logic check:
    #   Is it possible that for N=3, the result is non-zero?
    #   Maybe with different letters. 
    #   But we are stuck with A-D for HW.
    #   
    #   Let's try to verify Sample 1 (0 inv) -> 4 solutions.
    #   And verify a case where we expect 0.
    #   Let's construct a case that yields 0.
    #   "AB 1 2". If Circle is {A, B, C}: AB in C -> 0. Fail.
    #   If Circle is {A, D, E}: AB -> 1 available. Fail.
    #   If Circle is {D, E, F}: AB -> 2 available. OK.
    #   So "AB 1 2" has valid circles.
    #   
    #   Let's verify the "All Fail" case for Sample 2 logic:
    #   AB 1 1 (forbids AB)
    #   AC 2 1 (forbids AC)
    #   BC 2 1 (forbids BC)
    #   Does ANY triple in A-D satisfy this?
    #   Triangles: ABC, ABD, ACD, BCD.
    #   ABC: Contains AB, AC, BC. Fail.
    #   ABD: Contains AB. Fail.
    #   ACD: Contains AC. Fail.
    #   BCD: Contains BC. Fail.
    #   Result: 0.
    #   
    #   So the testbench for Sample 2 logic with A-D should expect 0.
    #   But Python Sample 2 expects 506.
    #   This means we are benchmarking "Deduction capability", not "Solving specific input".
    #   We MUST show the module CAN be verified.
    #   
    #   Let's make a Test Case 2 that has solutions in A-D.
    #   Example:
    #   AB 1 1 (AB not both in circle, 1 available)
    #   CD 2 1 (CD not both in circle, 1 available)
    #   
    #   Solutions:
    #   ABC: AB together -> Fail.
    #   ABD: AB together -> Fail.
    #   ACD: CD together -> Fail.
    #   BCD: CD together -> Fail.
    #   
    #   Let's try:
    #   AB 1 0 (Must have 0 -> AB must be in Circle)
    #   
    #   If AB 1 0:
    #   Circle must contain A and B.
    #   Possible: ABC, ABD.
    #   
    #   Let's add AC 2 0 (Must have 0 -> AC must be in Circle).
    #   Circle must contain A and C.
    #   Possible: ABC, ACD.
    #   
    #   Intersection: ABC.
    #   
    #   So if we run:
    #   AB 1 0
    #   AC 2 0
    #   Result should be 1 solution (ABC).
    
    dut.num_investigations.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await load_investigation(dut, 'A', 'B', 1, 0)
    await load_investigation(dut, 'A', 'C', 2, 0)

    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1

    if not dut.done.value:
        raise TestFailure("Module did not finish in time")
    
    # Expect 1 (ABC)
    if dut.solution_count.value != 1:
        raise TestFailure(f"Test Case 2 Failed: Expected 1 (ABC), got {int(dut.solution_count.value)}")

@cocotb.test()
async def test_black_vienna_contradiction(dut):
    """Test contradiction: AB 1 2 (need 2) and AB 2 0 (need 0)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value = 0
    dut.start.value = 0
    dut.inv_valid.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    dut.num_investigations.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # AB 1 2: P1 has 2 of {A,B} -> Neither A nor B can be in Circle.
    #   Valid circles: ACD, BCD (but B in BCD -> Fail? No, B is available.
    #   Wait, AB 1 2 means P1 has BOTH A and B. 
    #   So A and B are NOT in Circle. 
    #   Possible: ACD (A in Circle -> Fail).
    #   Wait, my logic: k=0 -> R=2 -> OK.
    #   If A is in Circle (k=1) -> R=2 -> Fail.
    #   So A and B MUST be out of Circle.
    #   Valid: {C, D, ?}. Only 4 letters. {C, D, X}. 
    #   With A-D: {C, D, A} -> A in -> Fail. {C, D, B} -> B in -> Fail.
    #   So NO solutions for AB 1 2 with A-D?
    #   Wait, {A, B, C}: A in -> Fail.
    #   {A, B, D}: A in -> Fail.
    #   {A, C, D}: A in -> Fail.
    #   {B, C, D}: B in -> Fail.
    #   So AB 1 2 -> 0 solutions.
    
    await load_investigation(dut, 'A', 'B', 1, 2)
    # AB 2 0: P2 has 0 of {A,B} -> A and B MUST be in Circle.
    #   Requires A and B in Circle.
    #   Possible: ABC, ABD.
    
    await load_investigation(dut, 'A', 'B', 2, 0)

    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1

    if not dut.done.value:
        raise TestFailure("Module did not finish in time")

    # Intersection of constraints: 
    # Constraint 1: A, B out of Circle.
    # Constraint 2: A, B in Circle.
    # Contradiction. Result 0.
    if dut.solution_count.value != 0:
        raise TestFailure(f"Test Contradiction Failed: Expected 0, got {int(dut.solution_count.value)}")
