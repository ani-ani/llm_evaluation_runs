import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_visual_parser_basic(dut):
    """Test basic matching with 2 pairs"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_pairs.value = 0
    for i in range(8):
        dut.tl_valid[i].value = 0
        dut.br_valid[i].value = 0
        dut.tl_row[i].value = 0
        dut.tl_col[i].value = 0
        dut.br_row[i].value = 0
        dut.br_col[i].value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Valid matching (Example 1 adapted)
    # Top-left: (4,7), (9,8)
    # Bottom-right: (14,17), (19,18) -> scaled to 8x8
    # Adapted: TL: (3,5), (6,5); BR: (7,7), (7,6)
    # Correct: TL0(3,5) -> BR1(7,6), TL1(6,5) -> BR0(7,7)
    
    dut.num_pairs.value = 2
    dut.tl_valid[0].value = 1
    dut.tl_row[0].value = 3
    dut.tl_col[0].value = 5
    dut.tl_valid[1].value = 1
    dut.tl_row[1].value = 6
    dut.tl_col[1].value = 5
    
    dut.br_valid[0].value = 1
    dut.br_row[0].value = 7
    dut.br_col[0].value = 7
    dut.br_valid[1].value = 1
    dut.br_row[1].value = 7
    dut.br_col[1].value = 6
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 1000 cycles)
    timeout = 1000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TestFailure("Timeout - done not asserted")
    
    if dut.valid.value == 1:
        # Check if match is correct
        # Expected: TL0->BR1 (index 1), TL1->BR0 (index 0)
        # OR TL0->BR0 (invalid), TL1->BR1 (invalid)
        # Valid matching: TL0(3,5) with BR1(7,6): 3<7 and 5<6 ✓
        # TL1(6,5) with BR0(7,7): 6<7 and 5<7 ✓
        # Check nesting/disjoint: Rect0 = 3-7,5-6; Rect1 = 6-7,5-7
        # They overlap partially? Rect0: row 3-7, col 5-6; Rect1: row 6-7, col 5-7
        # Intersection: row 6-7, col 5-6 (valid overlap) but are they nested?
        # Rect0 contains Rect1? Row 6-7 is within 3-7, but Col 5-6 is NOT within 5-7 (6 is in both)
        # Actually Rect1 extends to col 7, so not nested.
        # Are they disjoint? No, they share region row 6-7, col 5-6.
        # So this is partial overlap -> invalid! Must be syntax error.
        # Let's use Sample Input 2 adapted:
        # TL: (3,5), (7,5); BR: (7,7), (7,6)
        # Wait, let's use a simpler valid case.
        # Case: TL0(2,2), TL1(4,4); BR0(6,6), BR1(7,7)
        # TL0(2,2) -> BR0(6,6): Rect 2-6,2-6
        # TL1(4,4) -> BR1(7,7): Rect 4-7,4-7
        # Rect1 is nested in Rect0 (4>2, 7>6? 7>6, 4>2. Wait 4>2 is true, 4>2 is true. 
        # Nesting: R1 inside R0 requires: R0.r1 <= R1.r1 <= R1.r2 <= R0.r2 and same for cols.
        # Here R0: r=2-6, c=2-6; R1: r=4-7, c=4-7.
        # R1.r2=7 > R0.r2=6, so NOT nested. Disjoint? No overlap? R0 row 2-6, R1 row 4-7 -> overlap 4-6.
        # Col 2-6 vs 4-7 -> overlap 4-6.
        # So partial overlap. Invalid.
        # 
        # Let's try: TL0(1,1), BR0(3,3); TL1(4,4), BR1(6,6)
        # Disjoint. Valid.
        
        dut.tl_valid[0].value = 1
        dut.tl_row[0].value = 1
        dut.tl_col[0].value = 1
        dut.tl_valid[1].value = 1
        dut.tl_row[1].value = 4
        dut.tl_col[1].value = 4
        
        dut.br_valid[0].value = 1
        dut.br_row[0].value = 3
        dut.br_col[0].value = 3
        dut.br_valid[1].value = 1
        dut.br_row[1].value = 6
        dut.br_col[1].value = 6
        
        # Reset for new test
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        timeout = 1000
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        assert dut.valid.value == 1, f"Expected valid, got {dut.valid.value}"
        # Expected match: TL0->BR0 (idx 0), TL1->BR1 (idx 1)
        # Or swapped if valid? TL0->BR1 (1,1)->(6,6) valid. TL1->BR0 (4,4)->(3,3) invalid (4>3).
        # So only one valid match.
        assert dut.match_idx[0].value == 0, f"TL0 should match BR0, got {dut.match_idx[0].value}"
        assert dut.match_idx[1].value == 1, f"TL1 should match BR1, got {dut.match_idx[1].value}"
    else:
        raise TestFailure("Expected valid matching for disjoint rectangles")

@cocotb.test()
async def test_visual_parser_nested(dut):
    """Test nested rectangles"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Case: TL0(1,1), BR0(6,6); TL1(2,2), BR1(5,5)
    # Rect1 nested in Rect0. Valid.
    dut.num_pairs.value = 2
    dut.tl_valid[0].value = 1
    dut.tl_row[0].value = 1
    dut.tl_col[0].value = 1
    dut.tl_valid[1].value = 1
    dut.tl_row[1].value = 2
    dut.tl_col[1].value = 2
    
    dut.br_valid[0].value = 1
    dut.br_row[0].value = 6
    dut.br_col[0].value = 6
    dut.br_valid[1].value = 1
    dut.br_row[1].value = 5
    dut.br_col[1].value = 5
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 1000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    assert dut.valid.value == 1, "Nested rectangles should be valid"
    # Both matchings (0->0,1->1) and (0->1,1->0) are geometrically possible?
    # TL0(1,1)->BR1(5,5): 1<5, 1<5. TL1(2,2)->BR0(6,6): 2<6, 2<6.
    # Nested check: Rect A: 1-5, 1-5; Rect B: 2-6, 2-6.
    # Rect A inside B? No (A.r1=1 < B.r1=2). B inside A? No (B.r2=6 > A.r2=5).
    # Disjoint? No. Partial overlap. Invalid.
    # So only one valid matching.
    assert dut.match_idx[0].value == 0, "TL0 must match BR0"
    assert dut.match_idx[1].value == 1, "TL1 must match BR1"

@cocotb.test()
async def test_visual_parser_invalid(dut):
    """Test invalid overlapping rectangles (syntax error)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Case: TL0(2,2), TL1(4,4); BR0(6,4), BR1(6,6) -> Sample 3 adapted
    # TL0(2,2)->BR0(6,4): 2<6 but 2<4? No 2<4 is true. 
    # TL1(4,4)->BR1(6,6): 4<6, 4<6.
    # Rect0: row 2-6, col 2-4. Rect1: row 4-6, col 4-6.
    # Overlap? Row 4-6, Col 4-4 (line). 
    # Disjoint? No. Nested? Rect1 in Rect0 requires col 4-6 inside 2-4 -> 6>4 false.
    # Rect0 in Rect1 requires row 2-6 inside 4-6 -> 2<4 false.
    # So partial overlap -> Invalid.
    
    dut.num_pairs.value = 2
    dut.tl_valid[0].value = 1
    dut.tl_row[0].value = 2
    dut.tl_col[0].value = 2
    dut.tl_valid[1].value = 1
    dut.tl_row[1].value = 4
    dut.tl_col[1].value = 4
    
    dut.br_valid[0].value = 1
    dut.br_row[0].value = 6
    dut.br_col[0].value = 4
    dut.br_valid[1].value = 1
    dut.br_row[1].value = 6
    dut.br_col[1].value = 6
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 1000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    assert dut.valid.value == 0, "Overlapping rectangles should be invalid"

@cocotb.test()
async def test_visual_parser_single(dut):
    """Test single rectangle"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.num_pairs.value = 1
    dut.tl_valid[0].value = 1
    dut.tl_row[0].value = 2
    dut.tl_col[0].value = 2
    
    dut.br_valid[0].value = 1
    dut.br_row[0].value = 5
    dut.br_col[0].value = 5
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 1000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
            
    assert dut.valid.value == 1, "Single valid rectangle"
    assert dut.match_idx[0].value == 0, "TL0 match BR0"
