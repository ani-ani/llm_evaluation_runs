import cocotb
from cocotb.triggers import Timer

@cocotb.test()
def test_height_reassignment(dut):
    """Test the height reassignment logic for various rank scenarios"""
    
    # Test cases: (row_rank, col_rank, row_uniques, col_uniques, expected_result)
    # Logic: result = max(rank_row, rank_col) + max(remaining_row, remaining_col) + 1
    # where remaining = uniques - rank - 1
    
    test_cases = [
        # Case 1: Rank 0, 1 unique in row, 1 unique in col -> max(0,0) + max(0,0) + 1 = 1
        (0, 0, 1, 1, 1),
        
        # Case 2: Row rank 1, Col rank 0, Row unique 2, Col unique 1
        # max(1,0)=1, rem_row=2-1-1=0, rem_col=1-0-1=0, max(0,0)=0. Total=1+0+1=2
        (1, 0, 2, 1, 2),
        
        # Case 3: Row rank 0, Col rank 1, Row unique 1, Col unique 2
        # Same as above. Result=2
        (0, 1, 1, 2, 2),
        
        # Case 4: From Example 2, intersection (0,0) - values 1, 2, 3, 4
        # Row: [1, 2], Uniques: 2. Rank of 1 is 0.
        # Col: [1, 3], Uniques: 2. Rank of 1 is 0.
        # Result expected: 2.
        (0, 0, 2, 2, 2),
        
        # Case 5: From Example 2, intersection (0,1) - values 1, 2, 3, 4
        # Row: [1, 2], Uniques: 2. Rank of 2 is 1.
        # Col: [2, 4], Uniques: 2. Rank of 2 is 0.
        # max_rank=1, rem_row=0, rem_col=1. Result: 1+1+1=3.
        (1, 0, 2, 2, 3),
        
        # Case 6: Symmetric to Case 5 (intersection 1,0)
        # Row: [3, 4], Uniques: 2. Rank of 3 is 0.
        # Col: [1, 3], Uniques: 2. Rank of 3 is 1.
        # Result: 3.
        (0, 1, 2, 2, 3),
        
        # Case 7: Intersection (1,1)
        # Row: [3, 4], Uniques: 2. Rank of 4 is 1.
        # Col: [2, 4], Uniques: 2. Rank of 4 is 1.
        # max_rank=1, rem_row=0, rem_col=0. Result: 2.
        (1, 1, 2, 2, 2),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (rr, cr, ru, cu, expected) in enumerate(test_cases):
        dut.row_rank.value = rr
        dut.col_rank.value = cr
        dut.row_uniques.value = ru
        dut.col_uniques.value = cu
        
        # Combinational logic settles immediately
        await Timer(10, units='ns')
        
        actual = int(dut.min_max_x.value)
        
        if actual == expected:
            passed += 1
        else:
            print(f"Test {i+1} FAILED: Input (rr={rr}, cr={cr}, ru={ru}, cu={cu}). Expected {expected}, got {actual}")
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
