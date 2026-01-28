import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def pack_grid(grid, rows=8, cols=8, data_width=8):
    packed = [0] * (rows * cols)
    for i in range(rows):
        for j in range(cols):
            if i < len(grid) and j < len(grid[0]):
                val = grid[i][j]
                if val < 0:
                    val = 0
                elif val >= (1 << data_width):
                    val = (1 << data_width) - 1
                packed[i * cols + j] = val
            else:
                packed[i * cols + j] = 0
    return packed

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_karen_and_game(dut):
    # Initialize
    dut.start.value = 0
    dut.rst_n.value = 1
    await Timer(10, units='ns')
    
    # Reset
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(10, units='ns')
    
    # Test cases (scaled to 8x8)
    test_cases = [
        {  # Example 1: 3x5 -> padded to 8x8
            'grid': [
                [2,2,2,3,2],
                [0,0,0,1,0],
                [1,1,1,2,1]
            ],
            'expected_moves': 4,
            'expected_error': False,
            'description': 'Example 1 from problem'
        },
        {  # Example 2: 3x3 -> padded to 8x8
            'grid': [
                [0,0,0],
                [0,1,0],
                [0,0,0]
            ],
            'expected_moves': -1,
            'expected_error': True,
            'description': 'Example 2 from problem'
        },
        {  # Example 3: 3x3 -> padded to 8x8
            'grid': [
                [1,1,1],
                [1,1,1],
                [1,1,1]
            ],
            'expected_moves': 3,
            'expected_error': False,
            'description': 'Example 3 from problem'
        }
    ]
    
    for idx, test in enumerate(test_cases):
        dut._log.info(f"Test {idx+1}: {test['description']}")
        
        # Pack grid
        packed = pack_grid(test['grid'])
        for i in range(64):
            dut.grid_flat[i].value = packed[i]
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for computation to complete
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check error flag
        if is_value_defined(dut.error.value):
            if int(dut.error.value) != (1 if test['expected_error'] else 0):
                raise TestFailure(f"Test {idx+1}: Error flag mismatch. Expected {test['expected_error']}, got {dut.error.value}")
        
        # If error expected, skip move checking
        if test['expected_error']:
            continue
        
        # Check move count
        if is_value_defined(dut.move_count.value):
            move_count = int(dut.move_count.value)
            if move_count != test['expected_moves']:
                raise TestFailure(f"Test {idx+1}: Move count mismatch. Expected {test['expected_moves']}, got {move_count}")
        else:
            raise TestFailure(f"Test {idx+1}: move_count undefined")
        
        # Collect moves
        moves = []
        for _ in range(move_count):
            # Wait for output_valid
            timeout = 0
            while not dut.output_valid.value and timeout < 100:
                await RisingEdge(dut.clk)
                timeout += 1
            if timeout == 100:
                raise TestFailure(f"Test {idx+1}: Timeout waiting for move")
            
            # Capture move
            move_type = 'row' if int(dut.move_type.value) == 0 else 'col'
            move_idx = int(dut.move_index.value)
            moves.append(f"{move_type} {move_idx}")
            await RisingEdge(dut.clk)
        
        dut._log.info(f"Test {idx+1}: Passed with {len(moves)} moves")
        for move in moves:
            dut._log.info(f"  {move}")
    
    dut._log.info("All tests completed")
