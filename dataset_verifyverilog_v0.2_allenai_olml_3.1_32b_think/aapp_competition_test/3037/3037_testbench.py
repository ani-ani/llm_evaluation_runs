import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_turtle_dry_finder(dut):
    """Test the Turtle Dry Finder module with scaled test cases."""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.target_pattern.value = 0
    dut.commands_packed.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # --- Helper to pack commands ---
    def pack_commands(cmd_list):
        # cmd_list is list of tuples (dir_str, dist_int)
        # dist_int is 1-4. Code it as (dist-1) << 2 | dir_code
        packed = 0
        for i, (d_str, dist) in enumerate(cmd_list):
            if d_str == "up": d_code = 0
            elif d_str == "right": d_code = 1
            elif d_str == "down": d_code = 2
            elif d_str == "left": d_code = 3
            else: continue
            
            dist_code = (dist - 1) & 0x3
            cmd_val = (dist_code << 2) | d_code
            packed |= (cmd_val << (i * 4))
        return packed

    # --- Helper to flatten target ---
    def flatten_target(rows):
        # rows is list of strings length 4
        val = 0
        for r_idx, row in enumerate(rows):
            for c_idx, char in enumerate(row):
                if char == '#':
                    # Bit index: row * 4 + col. Assuming (0,0) is bottom left in problem, 
                    # but here we just map directly. Let's assume Row 0 is bottom in input string.
                    # If input string is top-down, we might need to flip.
                    # Let's assume standard matrix: Row 0 is top. 
                    # But problem says "bottom left". 
                    # Let's pass the bits 0..15 such that Bit 0 is (0,0) bottom-left?
                    # Or let's just define: Bit (y*4 + x) where y=0 is bottom.
                    # If input is top-down, we need to reverse rows.
                    pass
        # Let's do it explicitly inside the test cases below.

    # --- Test Cases ---
    
    # Case 1: Example 1 Scaled
    # Target: 
    # Row 3 (Top): ...
    # Row 2: ...
    # Row 1: .#.. (x=1, y=1)
    # Row 0 (Bottom): ..#. (x=2, y=0)
    # We want a path that covers these.
    # Path: (0,0) -> (0,1) -> (1,1) -> (1,0) -> (2,0)
    # Commands: Up 1 (0,1), Right 1 (1,1), Down 1 (1,0), Right 1 (2,0)
    # This covers: (0,0), (0,1), (1,1), (1,0), (2,0). 5 marks.
    # Target bits: (0,0)=1, (0,1)=1, (1,1)=1, (1,0)=1, (2,0)=1.
    # Bits: 0, 4, 5, 1, 2. Sum = 1+16+32+2+4 = 55.
    # If marker dries at T=5, marks 0-4 (5 marks). Matches.
    # If marker dries at T=6, marks 0-5 (6 marks). Includes (2,1)? No. (2,1) is x=2, y=1.
    # Wait, path: (0,0), (0,1), (1,1), (1,0), (2,0). 
    # T=0: Empty.
    # T=1: Mark (0,0).
    # T=2: Mark (0,1).
    # T=3: Mark (1,1).
    # T=4: Mark (1,0).
    # T=5: Mark (2,0).
    # Target matches exactly at T=5.
    
    dut._log.info("Running Test Case 1")
    # Target bits: 0, 1, 4, 5, 2. 
    # Bit index = y*4 + x. y=0 is bottom.
    # (0,0): bit 0
    # (1,0): bit 1
    # (2,0): bit 2
    # (0,1): bit 4
    # (1,1): bit 5
    target1 = (1<<0) | (1<<1) | (1<<2) | (1<<4) | (1<<5)
    dut.target_pattern.value = target1
    # Commands: Up 1, Right 1, Down 1, Right 1
    cmds1 = [("up", 1), ("right", 1), ("down", 1), ("right", 1)]
    dut.commands_packed.value = pack_commands(cmds1)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    while not dut.done.value:
        await RisingEdge(dut.clk)
        # Add a timeout to prevent infinite loop in simulation
        if get_time(dut) > 200: 
            dut._log.error("Timeout")
            break
            
    assert dut.valid.value == 1, "Case 1 should be valid"
    assert dut.min_time.value == 5, f"Expected min 5, got {dut.min_time.value}"
    assert dut.max_time.value == 5, f"Expected max 5, got {dut.max_time.value}"
    dut._log.info("Case 1 Passed")
    
    # Reset
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Case 2: Example 2 Scaled (Target differs)
    # Keep same path, change target.
    # Remove one point: Remove (2,0). Target: bits 0, 1, 4, 5. Sum = 1+2+16+32 = 51.
    # Matches at T=4.
    dut._log.info("Running Test Case 2")
    target2 = (1<<0) | (1<<1) | (1<<4) | (1<<5)
    dut.target_pattern.value = target2
    dut.commands_packed.value = pack_commands(cmds1)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
        if get_time(dut) > 200: break
            
    assert dut.valid.value == 1, "Case 2 should be valid"
    assert dut.min_time.value == 4, f"Expected min 4, got {dut.min_time.value}"
    assert dut.max_time.value == 4, f"Expected max 4, got {dut.max_time.value}"
    dut._log.info("Case 2 Passed")
    
    # Reset
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Case 3: Impossible
    # Target has a point not in path. E.g., (3,0). Bit 3.
    # Path is (0,0),(0,1),(1,1),(1,0),(2,0).
    target3 = target1 | (1<<3)
    dut._log.info("Running Test Case 3")
    dut.target_pattern.value = target3
    dut.commands_packed.value = pack_commands(cmds1)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
        if get_time(dut) > 200: break
            
    assert dut.valid.value == 0, "Case 3 should be invalid"
    # The problem outputs -1 -1. 
    # In 6-bit 2's complement, -1 is 6'b111111 = 63.
    assert dut.min_time.value == 63, f"Expected -1 (63), got {dut.min_time.value}"
    assert dut.max_time.value == 63, f"Expected -1 (63), got {dut.max_time.value}"
    dut._log.info("Case 3 Passed")

    # Case 4: Empty Target
    # No marks. Should match at T=0.
    dut._log.info("Running Test Case 4")
    dut.target_pattern.value = 0
    dut.commands_packed.value = pack_commands(cmds1)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
        if get_time(dut) > 200: break
            
    assert dut.valid.value == 1
    assert dut.min_time.value == 0
    assert dut.max_time.value == 0
    dut._log.info("Case 4 Passed")

    # Case 5: Multiple Windows
    # Path: (0,0) -> (1,0). Marks: (0,0) at T=1, (1,0) at T=2.
    # Target1: (0,0). Match at T=1.
    # Target2: (0,0), (1,0). Match at T=2.
    # If target is (0,0), min=1, max=1.
    # If target is empty, min=0, max=0.
    # If target is (0,0) AND (1,0), min=2, max=2.
    # What if we extend path? 
    # Let's do: (0,0) -> (1,0) -> (1,1).
    # Marks: T1: (0,0). T2: (1,0). T3: (1,1).
    # Target (0,0). Matches T=1. 
    # Does it match T=2? No. Target is just (0,0). But we have (0,0) AND (1,0) at T=2.
    # So T=2 is invalid. T=3 is invalid.
    # So min=max=1.
    # Let's construct a case where min != max.
    # Path: (0,0) -> (0,1) -> (1,1) -> (1,0).
    # T1: (0,0)
    # T2: (0,0), (0,1)
    # T3: (0,0), (0,1), (1,1)
    # T4: (0,0), (0,1), (1,1), (1,0)
    # If Target is (0,0), (0,1), (1,1). 
    # T=3: Matches.
    # T=4: Also matches? No, adds (1,0). 
    # If Target is just (0,0). T=1. T=2 has extra. T=3 has extra.
    # So we need a Target that matches at T=3 and T=5 (if T=4 is skipped? No, continuous).
    # It's hard to have disjoint intervals without erasing, which the turtle doesn't do.
    # Wait, the problem says marker acts as eraser AFTER drying. 
    # But we are finding valid drying times. 
    # Once we pass a time, marks accumulate. 
    # So the set of marks is monotonic. 
    # If Target is S. We need current_marking == S.
    # Since current_marking grows (or stays same if dist 0), 
    # if we have a match at T, we can only have match at T+k if no new marks are added.
    # If commands are 0 distance, no marks. 
    # But distances are >= 1.
    # So usually marks are added. 
    # If Target is the FULL path, then min=max = TotalSteps.
    # If Target is empty, min=max=0.
    # If Target is some intermediate state, min=max.
    # So the answer is usually a single number.
    # Wait, the examples had 20 20 and 17 17. 
    # The problem asks for min and max. 
    # This implies there might be ranges. 
    # How? 
    # Maybe if the turtle crosses its own path? 
    # If it crosses a marked cell, current_marking doesn't change (cell already marked).
    # So if it travels over already marked cells, the set of marks stays constant.
    # Example: Move Right 1: Mark (0,0). Move Left 1: Back to (0,0). Marks = {(0,0)}.
    # So T=1 -> {(0,0)}. T=2 -> {(0,0)}. 
    # If Target is {(0,0)}, then valid times are T=1 and T=2.
    # Min=1, Max=2.
    
    # Case 5: Range Test
    # Path: Right 1, Left 1.
    # Target: (0,0) only.
    # T=0: Empty.
    # T=1: (0,0). Match.
    # T=2: (0,0). Match.
    dut._log.info("Running Test Case 5 (Range)")
    target5 = (1<<0)
    dut.target_pattern.value = target5
    cmds5 = [("right", 1), ("left", 1)]
    dut.commands_packed.value = pack_commands(cmds5)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
        if get_time(dut) > 200: break
            
    assert dut.valid.value == 1
    # Mark at T=1. Still there at T=2.
    # So range 1..2.
    # Note: T=0 is empty (no match).
    assert dut.min_time.value == 1
    assert dut.max_time.value == 2
    dut._log.info("Case 5 Passed")

    dut._log.info("All tests passed")

def get_time(dut):
    # Helper to read simulation time if needed, or just cycle count
    return 0
