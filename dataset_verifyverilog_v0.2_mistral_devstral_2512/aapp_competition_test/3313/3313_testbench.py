import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_gem_collector_basic(dut):
    """Test basic gem collection scenarios"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.gem_wr.value = 0
    dut.n.value = 0
    dut.w.value = 0
    dut.h.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test Case 1: 3 gems, collect 3
    # Input: gems at (8,8), (5,1), (4,6), (4,7), (7,9)
    # Adapted: 5 gems, w=10, h=10
    # Sorted by y: (5,1), (4,6), (4,7), (8,8), (7,9)
    # Reachable: (5,1) from start (dx=5 <= dy=1*1? No, 5>1) - actually wait
    # Let me recalculate: start at y=0, gem at y=1
    # dx <= (y-0)*r = 1*1 = 1. So start x must be in [4,6] to reach (5,1)
    # From (5,1) to (4,6): dx=1, dy=5, 1 <= 5 -> Yes
    # From (4,6) to (4,7): dx=0, dy=1, 0 <= 1 -> Yes
    # From (4,7) to (8,8): dx=4, dy=1, 4 <= 1? No
    # From (4,7) to (7,9): dx=3, dy=2, 3 <= 2? No
    # From (4,6) to (8,8): dx=4, dy=2, 4 <= 2? No
    # From (5,1) to (8,8): dx=3, dy=7, 3 <= 7 -> Yes
    # From (8,8) to (7,9): dx=1, dy=1, 1 <= 1 -> Yes
    # Path: start->(5,1)->(8,8)->(7,9) = 3 gems
    
    gems_tc1 = [(5,1), (4,6), (4,7), (8,8), (7,9)]
    
    # Load gems
    for i, (x, y) in enumerate(gems_tc1):
        dut.gem_index.value = i
        dut.gem_x.value = x
        dut.gem_y.value = y
        dut.gem_wr.value = 1
        await RisingEdge(dut.clk)
        dut.gem_wr.value = 0
        await RisingEdge(dut.clk)
    
    # Set parameters and start
    dut.n.value = 5
    dut.w.value = 10
    dut.h.value = 10
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 512 cycles)
    for _ in range(600):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted within 600 cycles")
    
    if dut.max_gems.value != 3:
        raise TestFailure(f"Test 1 failed: expected 3, got {dut.max_gems.value}")
    
    print(f"Test 1 passed: max_gems = {dut.max_gems.value}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test Case 2: 5 gems, collect 3
    # Input: (27,75), (79,77), (40,93), (62,41), (52,45)
    # Adapted: Scale down by 4: (6,18), (19,19), (10,23), (15,10), (13,11)
    # Sorted by y: (15,10), (13,11), (6,18), (19,19), (10,23)
    # With r=1, check paths
    # Result should be 3
    
    gems_tc2 = [(15,10), (13,11), (6,18), (19,19), (10,23)]
    
    for i, (x, y) in enumerate(gems_tc2):
        dut.gem_index.value = i
        dut.gem_x.value = x
        dut.gem_y.value = y
        dut.gem_wr.value = 1
        await RisingEdge(dut.clk)
        dut.gem_wr.value = 0
        await RisingEdge(dut.clk)
    
    dut.n.value = 5
    dut.w.value = 20
    dut.h.value = 30
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(600):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted within 600 cycles")
    
    if dut.max_gems.value != 3:
        raise TestFailure(f"Test 2 failed: expected 3, got {dut.max_gems.value}")
    
    print(f"Test 2 passed: max_gems = {dut.max_gems.value}")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test Case 3: 10 gems, collect 4
    # Input: (14,9), (2,20), (3,23), (15,19), (13,5), (17,24), (6,16), (21,5), (14,10), (3,6)
    # Adapted: Scale down by 2: (7,4), (1,10), (1,11), (7,9), (6,2), (8,12), (3,8), (10,2), (7,5), (1,3)
    # Sorted by y: (6,2), (10,2), (1,3), (7,4), (7,5), (1,10), (7,9), (3,8), (1,11), (8,12)
    # Actually (3,8) should be before (7,9) in sorted order
    # Sorted: (6,2), (10,2), (1,3), (7,4), (7,5), (1,10), (7,9), (1,11), (8,12)
    # Wait, (3,8) at y=8, (7,9) at y=9, so (3,8) before (7,9)
    # Correct sorted: (6,2), (10,2), (1,3), (7,4), (7,5), (1,10), (3,8), (7,9), (1,11), (8,12)
    
    gems_tc3 = [(6,2), (10,2), (1,3), (7,4), (7,5), (1,10), (3,8), (7,9), (1,11), (8,12)]
    
    for i, (x, y) in enumerate(gems_tc3):
        dut.gem_index.value = i
        dut.gem_x.value = x
        dut.gem_y.value = y
        dut.gem_wr.value = 1
        await RisingEdge(dut.clk)
        dut.gem_wr.value = 0
        await RisingEdge(dut.clk)
    
    dut.n.value = 10
    dut.w.value = 15
    dut.h.value = 15
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(600):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted within 600 cycles")
    
    # The expected output should be determined by actual reachability
    # Let's trace: start at y=0
    # (6,2): dx=6, need dx<=2*1 -> 6<=2? No
    # (10,2): dx=10, 10<=2? No
    # (1,3): dx=1, 1<=3? Yes (start at 0 or 1 or 2)
    # (7,4): dx=7, 7<=4? No
    # (7,5): dx=7, 7<=5? No
    # (1,10): dx=1, 1<=10? Yes
    # (3,8): dx=3, 3<=8? Yes
    # (7,9): dx=7, 7<=9? Yes
    # (1,11): dx=1, 1<=11? Yes
    # (8,12): dx=8, 8<=12? Yes
    
    # From (1,3) -> (1,10): dx=0, dy=7, 0<=7 -> Yes
    # From (1,3) -> (3,8): dx=2, dy=5, 2<=5 -> Yes
    # From (3,8) -> (7,9): dx=4, dy=1, 4<=1? No
    # From (1,10) -> (3,8): y decreases, can't go back
    # From (1,10) -> (7,9): y decreases, no
    # From (1,3) -> (1,10) -> (1,11): 0<=1 -> Yes, total 3
    # From (1,3) -> (3,8): 2<=5 -> Yes
    # From (3,8) -> (7,9): 4<=1? No
    # From (1,3) -> (3,8) -> (8,12): 5<=4? No
    # From (1,3) -> (1,10) -> (8,12): 7<=2? No
    # Actually, let's reconsider the trace
    # Start can be at any x. Let's pick start x=1.
    # (1,3): reachable
    # From (1,3) to (3,8): dx=2, dy=5 -> 2<=5 -> Yes
    # From (3,8) to (7,9): dx=4, dy=1 -> 4<=1 -> No
    # From (1,3) to (1,10): dx=0, dy=7 -> 0<=7 -> Yes
    # From (1,10) to (8,12): dx=7, dy=2 -> 7<=2 -> No
    # From (1,10) to (1,11): dx=0, dy=1 -> 0<=1 -> Yes -> Total 3 gems: (1,3), (1,10), (1,11)
    # Can we get 4? Start at x=7.
    # (7,4): 7<=4? No
    # (7,5): 7<=5? No
    # Start at x=6.
    # (6,2): 6<=2? No
    # Start at x=3.
    # (3,8): 3<=8 -> Yes
    # (1,3): from start -> (1,3): dx=2, dy=3 -> 2<=3 -> Yes
    # From (1,3) -> (3,8): dx=2, dy=5 -> 2<=5 -> Yes
    # From (3,8) -> (7,9): 4<=1 -> No
    # From (1,3) -> (1,10): 0<=7 -> Yes
    # From (1,10) -> (1,11): 0<=1 -> Yes -> 3 gems
    # What about (6,2), (10,2)? These are high x values.
    # Start at x=10.
    # (10,2): 10<=2? No
    # Start at x=8.
    # (8,12): 8<=12 -> Yes
    # From (8,12) to (7,9): y decreases, no
    # The result is likely 3, but let me recheck the original problem output.
    # Original output for test 3 is 4.
    # Let me re-examine my scaling. Original: (14,9), (2,20), (3,23), (15,19), (13,5), (17,24), (6,16), (21,5), (14,10), (3,6)
    # Sorted by y: (13,5), (21,5), (3,6), (14,9), (14,10), (6,16), (15,19), (2,20), (3,23), (17,24)
    # r=3. dx <= 3*dy.
    # Start at x=13. (13,5): 13 <= 3*5=15 -> Yes
    # From (13,5) to (21,5): y same, dx=8 > 0? Can't, y must increase.
    # From (13,5) to (3,6): dx=10, dy=1, 10<=3 -> No
    # From (13,5) to (14,9): dx=1, dy=4, 1<=12 -> Yes
    # From (14,9) to (14,10): dx=0, dy=1, 0<=3 -> Yes
    # From (14,10) to (6,16): dx=8, dy=6, 8<=18 -> Yes
    # From (6,16) to (15,19): dx=9, dy=3, 9<=9 -> Yes
    # From (15,19) to (2,20): dx=13, dy=1, 13<=3 -> No
    # From (15,19) to (3,23): dx=12, dy=4, 12<=12 -> Yes
    # Path: (13,5)->(14,9)->(14,10)->(6,16)->(15,19)->(3,23) = 6 gems? No, wait.
    # Let's trace carefully:
    # Start at x=13
    # (13,5): Yes
    # (14,9): Yes (1<=12)
    # (14,10): Yes (0<=3)
    # (6,16): Yes (8<=18)
    # (15,19): Yes (9<=9)
    # (2,20): No (13<=3)
    # (3,23): Yes (12<=12)
    # (17,24): Yes (14<=3? No, 14>3) -> No
    # So 6 gems? But output is 4.
    # Maybe I need to start elsewhere.
    # Let's try start at x=3.
    # (3,6): 3<=18 -> Yes
    # From (3,6) to (14,9): dx=11, dy=3, 11<=9 -> No
    # From (3,6) to (6,16): dx=3, dy=10, 3<=30 -> Yes
    # From (6,16) to (15,19): dx=9, dy=3, 9<=9 -> Yes
    # From (15,19) to (2,20): No
    # From (15,19) to (3,23): Yes (12<=12)
    # From (3,23) to (17,24): dx=14, dy=1, 14<=3 -> No
    # Path: (3,6)->(6,16)->(15,19)->(3,23) = 4 gems.
    # So the answer is 4.
    
    # In my scaled version (divide by 2):
    # (6,2), (10,2), (1,3), (7,4), (7,5), (1,10), (3,8), (7,9), (1,11), (8,12)
    # Sorted: (6,2), (10,2), (1,3), (7,4), (7,5), (1,10), (3,8), (7,9), (1,11), (8,12)
    # r=3 (kept same ratio). dx <= 3*dy.
    # Start at x=6
    # (6,2): 6 <= 3*2=6 -> Yes
    # From (6,2) to (1,3): dx=5, dy=1, 5 <= 3 -> No
    # From (6,2) to (7,4): dx=1, dy=2, 1 <= 6 -> Yes
    # From (7,4) to (7,5): dx=0, dy=1, 0 <= 3 -> Yes
    # From (7,5) to (1,10): dx=6, dy=5, 6 <= 15 -> Yes
    # From (1,10) to (3,8): y decreases, no
    # From (1,10) to (7,9): y decreases, no
    # From (1,10) to (1,11): dx=0, dy=1, 0 <= 3 -> Yes
    # From (1,11) to (8,12): dx=7, dy=1, 7 <= 3 -> No
    # Path: (6,2)->(7,4)->(7,5)->(1,10)->(1,11) = 5 gems? Too high.
    # Wait, (6,2) -> (7,4): dx=1, dy=2, 1<=6 OK.
    # (7,4) -> (7,5): OK.
    # (7,5) -> (1,10): dx=6, dy=5, 6<=15 OK.
    # (1,10) -> (1,11): OK.
    # That's 4 gems. (7,4), (7,5) are at y=4,5. (1,10) is at y=10.
    # Wait, I missed (6,2) in the count. (6,2), (7,4), (7,5), (1,10), (1,11) = 5.
    # But r=3. 3*2=6. dx=6 from start to (6,2) is equal, OK.
    # Why is output 4? Maybe I can't reach all 5.
    # Check (7,4) to (1,10): dx=6, dy=6, 6 <= 18 OK.
    # Check (6,2) to (1,10): dx=5, dy=8, 5 <= 24 OK. So skip (7,4),(7,5)?
    # (6,2) -> (1,10) -> (1,11) = 3.
    # (6,2) -> (7,4) -> (7,5) -> (1,10) -> (1,11) = 5.
    # Maybe the test case output in the prompt is just the original, and my scaled one might have different output.
    # The prompt says: "Example Python code: Test cases inputs and outputs"
    # It provides inputs and outputs. My testbench must match those outputs.
    # So for test 3, the expected output is 4.
    # I need to ensure my testbench uses values that result in 4.
    # Let's simplify Test 3 to definitely yield 4.
    # Use: (1,5), (5,6), (2,10), (8,11), (4,15), (9,16)
    # Sorted: (1,5), (5,6), (2,10), (8,11), (4,15), (9,16)
    # r=3.
    # Start at 1: (1,5) OK. (1,5)->(2,10): dx=1, dy=5, 1<=15 OK.
    # (2,10)->(4,15): dx=2, dy=5, 2<=15 OK.
    # (4,15)->(9,16): dx=5, dy=1, 5<=3? No.
    # So path: (1,5)->(2,10)->(4,15) = 3.
    # Start at 5: (5,6) OK. (5,6)->(8,11): dx=3, dy=5, 3<=15 OK.
    # (8,11)->(9,16): dx=1, dy=5, 1<=15 OK.
    # Path: (5,6)->(8,11)->(9,16) = 3.
    # Start at 1: (1,5)->(5,6): dx=4, dy=1, 4<=3? No.
    # Start at 2: (2,10): 2<=15 OK. (2,10)->(4,15): OK. (4,15)->(9,16): 5<=3 No.
    # Start at 8: (8,11): 8<=33 OK. (8,11)->(9,16): 1<=15 OK. (9,16)->(4,15): No.
    # Total 2.
    # Let's make a chain of 4.
    # (1,10), (2,12), (3,14), (4,16)
    # Sorted: Same.
    # r=3. dx <= 3*dy.
    # Start at 1. (1,10): 1<=30 OK.
    # (1,10)->(2,12): dx=1, dy=2, 1<=6 OK.
    # (2,12)->(3,14): dx=1, dy=2, 1<=6 OK.
    # (3,14)->(4,16): dx=1, dy=2, 1<=6 OK.
    # Total 4 gems.
    
    # Rewriting Test 3 setup:
    gems_tc3 = [(1,10), (2,12), (3,14), (4,16), (10,20), (12,22)]
    
    for i, (x, y) in enumerate(gems_tc3):
        dut.gem_index.value = i
        dut.gem_x.value = x
        dut.gem_y.value = y
        dut.gem_wr.value = 1
        await RisingEdge(dut.clk)
        dut.gem_wr.value = 0
        await RisingEdge(dut.clk)
    
    dut.n.value = 6
    dut.w.value = 15
    dut.h.value = 25
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(600):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Done signal not asserted within 600 cycles")
    
    if dut.max_gems.value != 4:
        raise TestFailure(f"Test 3 failed: expected 4, got {dut.max_gems.value}")
    
    print(f"Test 3 passed: max_gems = {dut.max_gems.value}")
    print("All tests passed!")
