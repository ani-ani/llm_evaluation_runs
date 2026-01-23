import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
import random

# Helper to convert (r, c) to center coords (r+7, c+4)
def get_center(r, c):
    return (r + 7, c + 4)

# Convert center coord to 10-bit fixed point-ish representation (just bits)
def coord_to_bits(c):
    return c & 0x3FF # 10 bits

@cocotb.test()
async def test_min_moves(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.total_files.value = 0
    dut.num_delete.value = 0
    for i in range(10):
        dut.file_coords[i].value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')

    async def run_test_case(total, num_d, files_raw, expected_moves):
        # Reset for new test
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        dut.total_files.value = total
        dut.num_delete.value = num_d
        
        for i in range(total):
            r, c = files_raw[i]
            # Input format: {row[9:0], col[9:0]}
            # Note: We input raw pixel coords, the module handles center calculation
            # Wait, the prompt says 'file_coords' are inputs. Let's assume raw pixel coords are passed.
            # To keep interface simple, let's pass raw pixel coords.
            # Input format: 10-bit row, 10-bit col. 
            val = (coord_to_bits(r) << 10) | coord_to_bits(c)
            dut.file_coords[i].value = val
            
        for i in range(total, 10):
            dut.file_coords[i].value = 0

        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while dut.done.value == 0 and timeout < 10000:
            await RisingEdge(dut.clk)
            timeout += 1
            
        if timeout >= 10000:
            raise TimeoutError("Module did not finish in time")
            
        result = int(dut.min_moves.value)
        dut._log.info(f"Test: total={total}, del={num_d} -> Result: {result}, Expected: {expected_moves}")
        assert result == expected_moves, f"Expected {expected_moves} but got {result}"

    # Test Case 1: Sample Input
    # Screen 80x50, 3 delete (D), 2 keep (K)
    # D1: 75 5 (Center 82, 9)
    # D2: 25 20 (Center 32, 24)
    # D3: 50 35 (Center 57, 39)
    # K1: 50 5 (Center 57, 9)
    # K2: 25 35 (Center 32, 39)
    # Total 5 files. D1, D2, D3 are targets.
    # Bounding box of D1, D2, D3: Row 32-82, Col 9-39.
    # K1 (57,9) is on left edge. K2 (32,39) is on bottom-right corner.
    # Technically they are ON the boundary. The problem says "no icons in the box". 
    # If boundary is included, we must move some. The example output is 2.
    # Let's assume strict containment is required, or at least no overlap.
    # If we move K1 and K2, remaining D's fit.
    # If we move D1 and D2, remaining D3 is just one point, fits easily.
    # But we want minimum moves. If 0 works, answer is 0. Example says 2.
    # This implies K1 or K2 is inside/intersecting the delete rect.
    # If we move D1 and D2, D3 is left. 
    # If we move D2 and D3, D1 is left.
    # If we move D1 and D2, D3 is left. Bounding box is just D3 (width 0, height 0). 
    # Does this box contain K1 or K2? No. So moving 2 works.
    # Can we move 1? Try remove D1. Remaining D2(32,24), D3(57,39). Box [32,57] x [24,39].
    # K1(57,9) -> Col 9 < 24. Outside.
    # K2(32,39) -> Row 32, Col 39. ON boundary.
    # If boundary is forbidden, we must move K2 or D2/D3 to change bounds.
    # If we move K2, we still have D1, D2, D3. Box [32,82]x[9,39]. K1(57,9) on boundary. Fail.
    # If we move D2. Remaining D1(82,9), D3(57,39). Box [57,82]x[9,39].
    # K1(57,9) on boundary. K2(32,39) outside. Fail.
    # If we move D1. Remaining D2(32,24), D3(57,39). Box [32,57]x[24,39]. K2(32,39) on boundary. Fail.
    # So 1 move is impossible. 2 moves work.
    dut._log.info("Starting Test 1")
    await run_test_case(5, 3, [(75, 5), (25, 20), (50, 35), (50, 5), (25, 35)], 2)

    # Test Case 2: 1 delete, 1 keep. No move needed.
    # D: 50 50. K: 80 80.
    # Box for D is just (57, 57). K is far away.
    dut._log.info("Starting Test 2")
    await run_test_case(2, 1, [(50, 50), (80, 80)], 0)
    
    # Test Case 3: Close overlap
    # D at 0 0. K at 0 1. (Centers 7, 7 and 7, 8). 
    # Box for D is [7,7]x[7,7]. K is at 7,8. Outside (col 8 > 7). Wait.
    # Icons are 15x9. Center (r+7, c+4).
    # D: 0,0 -> Center 7, 4.
    # K: 0,1 -> Center 7, 5.
    # Box D: [7,7]x[4,4]. K is at 5. Outside. So 0 moves.
    # Let's put K exactly on D edge.
    # D: 0,0 -> Center 7,4.
    # K: 0,0 -> No, different locations required. 
    # K: 0,4 -> Center 7,8. Box D width 0 (4 to 4). K col 8. Outside.
    # Need to force intersection.
    # D: 0,0 -> (7,4). Box: 4 to 4.
    # K: 0,3 -> (7,7). Box D: 4. K: 7. Outside.
    # K: 0,0 -> Same as D. Not allowed (no two icons same location).
    # Let's try D: 0,0 (7,4). K: 1,0 (8,4).
    # Box D: [7,7]x[4,4]. K: 8,4. Row 8 > 7. Outside.
    # Let's try D: 0,0 (7,4). K: 0,0 -> overlaps, not allowed.
    # Let's try D: 0,0 (7,4). K: -1, 0 -> negative, invalid.
    # Okay, let's make a case where 1 move is needed.
    # D at 0,0 (7,4). Keep at 0,0 -> Can't.
    # Let's use 2 D and 1 K.
    # D1: 0,0 -> (7,4). D2: 10,0 -> (17,4).
    # K: 5,0 -> (12,4).
    # Bounding box D: [7,17]x[4,4]. K: (12,4). INSIDE.
    # To fix: Move K (1 move) -> valid. Or move D1 (1 move) -> remaining D2. Valid.
    # So answer 1.
    dut._log.info("Starting Test 3")
    await run_test_case(3, 2, [(0, 0), (10, 0), (5, 0)], 1)

    # Test Case 4: 2 D, 2 K. All separated. 0 moves.
    # D: 0,0 (7,4), 10,0 (17,4). K: 0,10 (7,14), 10,10 (17,14).
    # Box D: [7,17]x[4,4]. K's are at col 14. Outside.
    dut._log.info("Starting Test 4")
    await run_test_case(4, 2, [(0, 0), (10, 0), (0, 10), (10, 10)], 0)

    # Test Case 5: The 'move 2' case but structured simply.
    # 3 D close, 2 K blocking corners.
    # D: 0,0 (7,4), 0,10 (7,14), 10,10 (17,14). Box [7,17]x[4,14].
    # K1: 0,0 -> (7,4). Same as D1. Not allowed.
    # Let's shift K1 to 1,0 -> (8,4). Box D col 4. K1 col 4. Row 8 in [7,17]. 
    # If K is ON boundary, is it "in the box"? Problem: "icon is considered in the box if its center is in the box". 
    # Usually implies inclusive. So yes.
    # So K1 blocks. K2: 10,10 -> (17,14). Box D row 17. K2 row 17. Col 14 in [4,14]. On boundary.
    # So both K's are on boundary. We must move D's to shrink box or move K's.
    # If we move D1 and D2, left with D3(10,10). Box [17,17]x[14,14]. K1(8,4) outside. K2(17,14) on boundary.
    # Wait, if we keep only D3, we can delete it alone. But we need to delete ALL n files. 
    # "delete all of the icons of files to be deleted".
    # So we can't just leave one. We must keep ALL remaining targets in ONE rect.
    # So we can't move 2 D's if we have 3 D's, unless we move 1 K to free up the rect.
    # If we move K1 (1), K2 (1) -> 0 D moved. Rect for all 3 D's is valid.
    # If we move D1 (1) -> Remaining D2, D3. Box [7,17]x[14,14]. K1(8,4) outside. K2(17,14) on boundary. 
    # Still invalid (boundary overlap). 
    # If we move D2 (1) -> D1, D3. Box [7,17]x[4,14]. Both K's on boundary. Invalid.
    # If we move D3 (1) -> D1, D2. Box [7,7]x[4,14]. Both K's outside. VALID.
    # Wait, D1(0,0), D2(0,10). 
    # K1(1,0) -> (8,4). Box D: [7,7]x[4,14]. K1 Row 8 > 7. Outside. 
    # K2(10,10) -> (17,14). Row 17 > 7. Outside.
    # So moving 1 D works! Answer should be 1.
    # But example 1 had answer 2. Why?
    # Example 1: D1(75,5), D2(25,20), D3(50,35). K1(50,5), K2(25,35).
    # Centers: D1(82,9), D2(32,24), D3(57,39). K1(57,9), K2(32,39).
    # Bounding box D: R [32,82], C [9,39].
    # K1: R57 (in range), C9 (boundary). Inside/On.
    # K2: R32 (boundary), C39 (boundary). Inside/On.
    # Try moving 1 D:
    # Move D1: Remaining D2(32,24), D3(57,39). Box R [32,57], C [24,39].
    # K1(57,9): R57 (boundary), C9 (<24). Outside.
    # K2(32,39): R32 (boundary), C39 (boundary). On. INVALID.
    # Move D2: Remaining D1(82,9), D3(57,39). Box R [57,82], C [9,39].
    # K1(57,9): R57, C9. On. INVALID.
    # K2(32,39): R32 (<57). Outside.
    # Move D3: Remaining D1(82,9), D2(32,24). Box R [32,82], C [9,24].
    # K1(57,9): On. INVALID.
    # K2(32,39): C39 (>24). Outside.
    # So 1 move fails. 
    # Try moving 2 D's:
    # Keep D3: Box [57,57]x[39,39]. K1(57,9) Row 57, C9 < 39. Outside. K2(32,39) Row 32 < 57. Outside.
    # VALID. 
    # So answer is 2.
    # My Test Case 5 analysis: D3(10,10). K2(10,10). Same location. Not allowed in input.
    # Let's make a valid Test 5.
    # D1(0,0), D2(0,10), D3(10,10). K1(1,0), K2(10,10) -> overlap invalid.
    # K2(10,11) -> (17,15). D3(10,10) -> (17,14). Box D: [7,17]x[4,14]. K2(17,15) C15>14, outside.
    # K1(1,0) -> (8,4). D1(0,0)->(7,4). Box D: [7,17]x[4,14]. K1(8,4) On boundary. INVALID.
    # Move D3: Remaining D1(7,4), D2(7,14). Box [7,7]x[4,14]. K1(8,4) Row 8 > 7. Outside.
    # K2(17,15) Row 17 > 7. Outside. VALID.
    # So answer 1.
    dut._log.info("Starting Test 5")
    await run_test_case(5, 3, [(0, 0), (0, 10), (10, 10), (1, 0), (10, 11)], 1)

    # Test Case 6: All 10 files used. Random-ish.
    # 5 Delete, 5 Keep. 
    # Make them all close so only 1 move helps?
    # D: 0,0 (7,4), 0,2 (7,6), 0,4 (7,8), 0,6 (7,10), 0,8 (7,12).
    # K: 0,1 (7,5), 0,3 (7,7), 0,5 (7,9), 0,7 (7,11), 0,9 (7,13).
    # D box: [7,7]x[4,12]. K's are interleaved. All K's are INSIDE.
    # We need to clear a gap. Move all 5 K's -> 5 moves. 
    # Or move 3 D's? If we keep D(0,0), D(0,8). Box [7,7]x[4,12]. K(0,1) inside.
    # If we keep D(0,0), D(0,2). Box [7,7]x[4,6]. K(0,1) inside.
    # If we keep D(0,0), D(0,4). Box [7,7]x[4,8]. K(0,1), (0,3) inside.
    # Actually, any pair of D's with a gap has a K inside.
    # If we keep D(0,0) only, 4 D moved. 1 D kept. Box [7,7]x[4,4]. K's all outside (col >4).
    # So 4 moves.
    # Can we do better? No.
    dut._log.info("Starting Test 6")
    await run_test_case(10, 5, [
        (0,0), (0,2), (0,4), (0,6), (0,8),
        (0,1), (0,3), (0,5), (0,7), (0,9)
    ], 4)

    dut._log.info("All tests passed!")