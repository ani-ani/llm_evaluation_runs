import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_treasure_map_assembler(dut):
    """Test the treasure map assembler module"""
    
    # Helper to convert a 2x2 grid (list of lists) to 8-bit integer
    def pack_piece(grid):
        # grid is 2x2 list of integers (0-3)
        # Order: [0][0], [0][1], [1][0], [1][1]
        val = 0
        val |= (grid[0][0] & 0x3)
        val |= ((grid[0][1] & 0x3) << 2)
        val |= ((grid[1][0] & 0x3) << 4)
        val |= ((grid[1][1] & 0x3) << 6)
        return val

    # Helper to check validity of a 4x4 map (list of lists of ints)
    def check_validity(grid):
        # Find treasure (0)
        treasure_pos = []
        for r in range(4):
            for c in range(4):
                if grid[r][c] == 0:
                    treasure_pos.append((r, c))
        
        if len(treasure_pos) != 1:
            return False
        
        tx, ty = treasure_pos[0]
        for r in range(4):
            for c in range(4):
                dist = abs(r - tx) + abs(c - ty)
                expected = dist % 4
                if grid[r][c] != expected:
                    return False
        return True

    # Helper to apply permutation config to pieces
    # Config 0: [P1, P2, P3, P4]
    # Config 1: [P1, P3, P2, P4]
    # Config 2: [P2, P1, P4, P3]
    # Config 3: [P4, P2, P3, P1]
    def apply_config(pieces, config):
        if config == 0:
            return [pieces[0], pieces[1], pieces[2], pieces[3]]
        elif config == 1:
            return [pieces[0], pieces[2], pieces[1], pieces[3]]
        elif config == 2:
            return [pieces[1], pieces[0], pieces[3], pieces[2]]
        elif config == 3:
            return [pieces[3], pieces[1], pieces[2], pieces[0]]

    # Helper to reconstruct 4x4 grid from pieces and permutation
    def reconstruct_grid(pieces_ordered):
        # pieces_ordered is [TL, TR, BL, BR]
        # TL = Top-Left (0,0)-(1,1)
        # TR = Top-Right (0,2)-(1,3)
        # BL = Bottom-Left (2,0)-(3,1)
        # BR = Bottom-Right (2,2)-(3,3)
        
        grid = [[0]*4 for _ in range(4)]
        
        # Process TL
        p = pieces_ordered[0]
        grid[0][0] = (p >> 0) & 0x3
        grid[0][1] = (p >> 2) & 0x3
        grid[1][0] = (p >> 4) & 0x3
        grid[1][1] = (p >> 6) & 0x3
        
        # Process TR
        p = pieces_ordered[1]
        grid[0][2] = (p >> 0) & 0x3
        grid[0][3] = (p >> 2) & 0x3
        grid[1][2] = (p >> 4) & 0x3
        grid[1][3] = (p >> 6) & 0x3
        
        # Process BL
        p = pieces_ordered[2]
        grid[2][0] = (p >> 0) & 0x3
        grid[2][1] = (p >> 2) & 0x3
        grid[3][0] = (p >> 4) & 0x3
        grid[3][1] = (p >> 6) & 0x3
        
        # Process BR
        p = pieces_ordered[3]
        grid[2][2] = (p >> 0) & 0x3
        grid[2][3] = (p >> 2) & 0x3
        grid[3][2] = (p >> 4) & 0x3
        grid[3][3] = (p >> 6) & 0x3
        
        return grid

    # Test Case 1: Valid configuration
    # Let's design a valid map manually to ensure we can test a positive case.
    # Treasure at (1,1). 
    # Distances:
    # (1,1) = 0
    # (0,0) = 2, (0,1)=1, (0,2)=1, (0,3)=2
    # (1,0)=1, (1,2)=1, (1,3)=2
    # (2,0)=1, (2,1)=1, (2,2)=1, (2,3)=2
    # (3,0)=2, (3,1)=2, (3,2)=2, (3,3)=3
    # Modulo 4:
    # 2 1 1 2
    # 1 0 1 2
    # 1 1 1 2
    # 2 2 2 3
    
    # We need to split this into 4 2x2 pieces.
    # TL (0,0): [[2,1],[1,0]] -> 2,1,1,0 -> bits: 2 | (1<<2) | (1<<4) | (0<<6) = 2 + 4 + 16 = 22 (0x16)
    # TR (0,2): [[1,2],[1,2]] -> 1,2,1,2 -> 1 | (2<<2) | (1<<4) | (2<<6) = 1 + 8 + 16 + 128 = 153 (0x99)
    # BL (2,0): [[1,1],[2,2]] -> 1,1,2,2 -> 1 | (1<<2) | (2<<4) | (2<<6) = 1 + 4 + 32 + 128 = 165 (0xA5)
    # BR (2,2): [[1,2],[2,3]] -> 1,2,2,3 -> 1 | (2<<2) | (2<<4) | (3<<6) = 1 + 8 + 32 + 192 = 233 (0xE9)
    
    p1 = 22   # 0x16
    p2 = 153  # 0x99
    p3 = 165  # 0xA5
    p4 = 233  # 0xE9
    
    # If we use Config 0 (P1, P2, P3, P4), we should get the correct map.
    
    dut.p1_data.value = p1
    dut.p2_data.value = p2
    dut.p3_data.value = p3
    dut.p4_data.value = p4
    dut.config.value = 0
    
    await Timer(10, units='ns')
    
    # Check outputs
    map_val = dut.map_out.value
    valid_val = dut.valid.value
    
    # Extract map from DUT
    # map_out is 32 bits. 2 bits per cell.
    # Row 0: bits 0-7
    # Row 1: bits 8-15
    # Row 2: bits 16-23
    # Row 3: bits 24-31
    
    dut_grid = [[0]*4 for _ in range(4)]
    for r in range(4):
        row_val = (map_val >> (8*r)) & 0xFF
        for c in range(4):
            dut_grid[r][c] = (row_val >> (2*c)) & 0x3
            
    print(f"
Test Case 1: Config 0 (Valid)")
    print(f"Input Pieces: P1={p1}, P2={p2}, P3={p3}, P4={p4}")
    print(f"DUT Map:")
    for r in range(4):
        print(f"  {dut_grid[r]}")
    print(f"DUT Valid: {valid_val}")
    
    # Calculate expected
    expected_grid = reconstruct_grid(apply_config([p1, p2, p3, p4], 0))
    expected_valid = check_validity(expected_grid)
    
    print(f"Expected Map:")
    for r in range(4):
        print(f"  {expected_grid[r]}")
    print(f"Expected Valid: {expected_valid}")
    
    assert valid_val == expected_valid, "Valid signal mismatch"
    # Check map content
    for r in range(4):
        for c in range(4):
            assert dut_grid[r][c] == expected_grid[r][c], f"Mismatch at ({r},{c}): DUT {dut_grid[r][c]} vs Exp {expected_grid[r][c]}"

    # Test Case 2: Invalid configuration
    # Let's swap P3 and P4 in Config 0. 
    # P1, P2, P4, P3.
    # P4 is [[1,2],[2,3]], P3 is [[1,1],[2,2]].
    # Top Left: P1 (2,1 / 1,0)
    # Top Right: P2 (1,2 / 1,2)
    # Bottom Left: P4 (1,2 / 2,3)
    # Bottom Right: P3 (1,1 / 2,2)
    # This will likely break the distance property.
    
    # Config 2 is [P2, P1, P4, P3] (Top-Left, Top-Right, Bottom-Left, Bottom-Right)
    # Let's use Config 2.
    dut.config.value = 2
    await Timer(10, units='ns')
    
    valid_val = dut.valid.value
    dut.config.value = 0 # Reset to avoid confusion
    
    print(f"
Test Case 2: Config 2 (Permutation)")
    print(f"DUT Valid: {valid_val}")
    
    # Calculate expected for Config 2
    expected_grid_2 = reconstruct_grid(apply_config([p1, p2, p3, p4], 2))
    expected_valid_2 = check_validity(expected_grid_2)
    print(f"Expected Valid: {expected_valid_2}")
    
    assert valid_val == expected_valid_2, "Valid signal mismatch for Config 2"
    
    # Test Case 3: Another Config
    # Config 1: [P1, P3, P2, P4]
    dut.config.value = 1
    await Timer(10, units='ns')
    valid_val = dut.valid.value
    
    expected_grid_3 = reconstruct_grid(apply_config([p1, p2, p3, p4], 1))
    expected_valid_3 = check_validity(expected_grid_3)
    
    print(f"
Test Case 3: Config 1")
    print(f"DUT Valid: {valid_val}")
    print(f"Expected Valid: {expected_valid_3}")
    assert valid_val == expected_valid_3

    # Test Case 4: Config 3
    dut.config.value = 3
    await Timer(10, units='ns')
    valid_val = dut.valid.value
    
    expected_grid_4 = reconstruct_grid(apply_config([p1, p2, p3, p4], 3))
    expected_valid_4 = check_validity(expected_grid_4)
    
    print(f"
Test Case 4: Config 3")
    print(f"DUT Valid: {valid_val}")
    print(f"Expected Valid: {expected_valid_4}")
    assert valid_val == expected_valid_4

    print("
All tests passed!")
