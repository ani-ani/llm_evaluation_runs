import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

def calculate_spread(pieces):
    """Calculate spread (sum of Chebyshev distances) for list of pieces"""
    if len(pieces) <= 1:
        return 0
    spread = 0
    for i in range(len(pieces)):
        for j in range(i + 1, len(pieces)):
            r1, c1 = pieces[i]
            r2, c2 = pieces[j]
            dist = max(abs(r1 - r2), abs(c1 - c2))
            spread += dist
    return spread

def encode_board(board_str):
    """Encode board string to list of 16 values (0=empty, 1=M, 2=S)"""
    encoded = []
    for char in board_str:
        if char == '.':
            encoded.append(0)
        elif char == 'M':
            encoded.append(1)
        elif char == 'S':
            encoded.append(2)
    return encoded

def get_pieces_from_board(board_data, player):
    """Extract piece coordinates for a player from 16-cell encoded board"""
    pieces = []
    for idx, val in enumerate(board_data):
        if val == player:
            row = idx // 4
            col = idx % 4
            pieces.append((row, col))
    return pieces

@cocotb.test()
async def test_chess_spread(dut):
    """Test chess spread calculator with multiple scenarios"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.board_data.value = 0
    dut.board_index.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # Case 1: 2x3 board mapped to 4x4 (SMS, MMS)
        # Original: M at (0,1), (1,0), (1,1) | S at (0,0), (1,2)
        # 4x4 mapping: Row0: SMS. | Row1: MMS. | Row2: .... | Row3: ....
        """S M S .
            M M S .
            . . . .
            . . . .""",
        # Case 2: 2x3 (S.M, M..)
        # Original: S at (0,0), M at (0,2), M at (1,0)
        # 4x4 mapping: Row0: S . M . | Row1: M . . . | Row2: .... | Row3: ....
        """S . M .
            M . . .
            . . . .
            . . . .""",
        # Case 3: More pieces
        """M . . .
            . S S .
            . S . M
            . . M ."""
    ]
    
    expected_outputs = [
        (3, 5),   # Mirko, Slavko
        (2, 0),
        (6, 4)    # Calculated: M pieces (0,0), (2,3), (3,2) -> pairs: (0,0)-(2,3)=3, (0,0)-(3,2)=3, (2,3)-(3,2)=1 | S pieces (1,1), (1,2), (2,1) -> pairs: (1,1)-(1,2)=1, (1,1)-(2,1)=1, (1,2)-(2,1)=1
    ]
    
    for idx, (board_str, expected) in enumerate(zip(test_cases, expected_outputs)):
        print(f"
=== Test Case {idx + 1} ===")
        
        # Parse board string
        board_lines = board_str.strip().split('
')
        flat_board = []
        for line in board_lines:
            cells = line.strip().split()
            flat_board.extend(cells)
        
        # Encode board
        encoded_board = encode_board(''.join(flat_board))
        print(f"Encoded board: {encoded_board}")
        
        # Collect pieces for verification
        mirko_pieces = get_pieces_from_board(encoded_board, 1)
        slavko_pieces = get_pieces_from_board(encoded_board, 2)
        
        expected_m = calculate_spread(mirko_pieces)
        expected_s = calculate_spread(slavko_pieces)
        print(f"Expected: M={expected_m}, S={expected_s}")
        print(f"Pieces: M at {mirko_pieces}, S at {slavko_pieces}")
        
        # Reset for new test
        dut.rst_n.value = 0
        await Timer(20, units='ns')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Input 16 board cells sequentially
        for i in range(16):
            dut.board_data.value = encoded_board[i]
            dut.board_index.value = i
            await RisingEdge(dut.clk)
        
        # Wait for computation to complete
        timeout = 50
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            raise TestFailure(f"Test {idx+1}: Timeout waiting for done signal")
        
        # Read outputs
        mirko_result = int(dut.mirko_spread.value)
        slavko_result = int(dut.slavko_spread.value)
        
        print(f"Got: M={mirko_result}, S={slavko_result}")
        
        # Assertions
        if mirko_result != expected_m:
            raise TestFailure(f"Test {idx+1}: Mirko spread mismatch. Expected {expected_m}, got {mirko_result}")
        if slavko_result != expected_s:
            raise TestFailure(f"Test {idx+1}: Slavko spread mismatch. Expected {expected_s}, got {slavko_result}")
        
        print(f"Test {idx+1} PASSED")
    
    print(f"
=== SUMMARY: {len(test_cases)}/{len(test_cases)} tests passed ===")