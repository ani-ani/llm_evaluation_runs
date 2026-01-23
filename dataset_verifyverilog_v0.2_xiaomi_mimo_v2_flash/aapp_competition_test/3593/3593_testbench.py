import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure, TestSuccess
import random

def calculate_max_sum(board, N, K):
    """Calculate maximum sum using K dominoes on N×3 board"""
    # Use dynamic programming with memoization
    from functools import lru_cache
    
    @lru_cache(None)
    def dp(row, k, prev_covered):
        # prev_covered: bitmask for columns covered by vertical domino from previous row
        # bit 0 = col 0, bit 1 = col 1, bit 2 = col 2
        if row >= N:
            return 0 if k == 0 and prev_covered == 0 else -float('inf')
        if k < 0:
            return -float('inf')
        
        best = -float('inf')
        
        # Try all valid configurations for this row
        # Enumerate horizontal domino placements
        for h_config in range(8):  # 3 bits for 3 columns, 1 means start horizontal there
            # h_config bits: 0=col0,1=col1,2=col2 (but horizontal covers 2 cols)
            covered = prev_covered
            score = 0
            valid = True
            used = 0
            
            # Check horizontal domino starting at column 0 (covers 0-1)
            if h_config & 1:
                if (covered & 3) != 0:  # cols 0 or 1 already covered
                    valid = False
                else:
                    covered |= 3  # mark cols 0,1 covered
                    score += board[row][0] + board[row][1]
                    used += 1
            
            # Check horizontal domino starting at column 1 (covers 1-2)
            if h_config & 2:
                if (covered & 6) != 0:  # cols 1 or 2 already covered
                    valid = False
                else:
                    covered |= 6  # mark cols 1,2 covered
                    score += board[row][1] + board[row][2]
                    used += 1
                    if h_config & 1:  # can't have both overlapping at col 1
                        valid = False
            
            if not valid:
                continue
            
            # Now try vertical dominoes for uncovered columns
            for v_config in range(8):  # which columns to place vertical domino
                v_used = 0
                v_score = 0
                v_covered = covered
                v_valid = True
                
                for col in range(3):
                    if v_config & (1 << col):
                        if v_covered & (1 << col):  # already covered
                            v_valid = False
                            break
                        if row + 1 >= N:  # can't place vertical at last row
                            v_valid = False
                            break
                        v_covered |= (1 << col)  # this row covered
                        # next row will have this col covered in prev_covered
                        v_score += board[row][col] + board[row + 1][col]
                        v_used += 1
                
                if not v_valid:
                    continue
                
                total_used = used + v_used
                if total_used <= k:
                    # For next row, compute new prev_covered
                    # Any column where we placed vertical domino at this row
                    # will be covered in next row
                    next_prev = 0
                    for col in range(3):
                        if v_config & (1 << col):
                            next_prev |= (1 << col)
                    
                    result = score + v_score + dp(row + 1, k - total_used, next_prev)
                    best = max(best, result)
        
        # Also try placing nothing in this row (only if prev_covered == 0 or we skip)
        if prev_covered == 0:
            # Can skip this row entirely
            result = dp(row + 1, k, 0)
            best = max(best, result)
        
        return best
    
    return dp(0, K, 0)

@cocotb.test()
async def test_chess_domino_max_sum(dut):
    """Test chess domino max sum module"""
    
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.row_index.value = 0
    dut.board_value.value = 0
    dut.K.value = 0
    dut.N.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Example from problem
    board1 = [
        [2, 1, -1],
        [1, 3, 2],
        [0, 2, 3],
        [2, 1, 1],
        [3, 3, 0]
    ]
    N1 = 5
    K1 = 3
    expected1 = 16
    
    # Test case 2: Example from problem
    board2 = [
        [0, 4, 1],
        [3, 5, 1]
    ]
    N2 = 2
    K2 = 2
    expected2 = 13
    
    # Test case 3: Single row
    board3 = [
        [10, 20, 30]
    ]
    N3 = 1
    K3 = 1
    # Best: horizontal 0-1 or 1-2: max(10+20=30, 20+30=50) = 50
    expected3 = 50
    
    # Test case 4: All negative
    board4 = [
        [-1, -2, -3],
        [-4, -5, -6]
    ]
    N4 = 2
    K4 = 1
    # Best: least negative horizontal in row 0: -1 + -2 = -3
    expected4 = -3
    
    test_cases = [
        (board1, N1, K1, expected1),
        (board2, N2, K2, expected2),
        (board3, N3, K3, expected3),
        (board4, N4, K4, expected4)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, (board, N, K, expected) in enumerate(test_cases):
        print(f"
Test case {idx + 1}: N={N}, K={K}")
        print(f"Board:")
        for row in board:
            print(f"  {row}")
        print(f"Expected: {expected}")
        
        # Load board values
        dut.N.value = N
        dut.K.value = K
        
        for row_idx in range(8):  # Always write 8 rows for simplicity
            for col in range(3):
                dut.row_index.value = row_idx
                if row_idx < N:
                    dut.board_value.value = board[row_idx][col] & 0xFFFFFFFF
                else:
                    dut.board_value.value = 0
                await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal with timeout
        timeout = 10000
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1 and dut.valid.value == 1:
                break
        else:
            raise TestFailure(f"Test case {idx + 1}: Timeout waiting for done signal")
        
        # Read result
        result = int(dut.max_sum.value)
        # Sign extend if needed
        if result >= (1 << 31):
            result -= (1 << 32)
        
        print(f"Got: {result}")
        
        if result == expected:
            passed += 1
            print(f"PASS")
        else:
            raise TestFailure(f"Test case {idx + 1}: Expected {expected}, got {result}")
    
    print(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    if passed == total:
        raise TestSuccess("All tests passed!")
