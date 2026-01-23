import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_robot_path_fixer(dut):
    """Test robot path fixer with multiple scenarios"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper to encode grid
    def encode_grid(grid_str):
        # grid_str is 16 chars, each char: ., #, S, G
        # return as array of 16 values
        grid = []
        for c in grid_str:
            if c == '.': grid.append(0)
            elif c == '#': grid.append(1)
            elif c == 'S': grid.append(2)
            elif c == 'G': grid.append(3)
        return grid
    
    # Helper to encode commands
    def encode_commands(cmd_str):
        cmd_map = {'L': 0, 'R': 1, 'U': 2, 'D': 3}
        encoded = 0
        for i, c in enumerate(cmd_str):
            encoded |= (cmd_map[c] << (2*i))
        return encoded, len(cmd_str)
    
    test_cases = [
        # Test case 1: Simple path, 0 edits needed
        # Grid: 4x4, S at (0,0), G at (3,3), no obstacles
        # Commands: RRDD (should work)
        {
            'grid': 'S.........#.....G',  # 4x4 = 16 chars
            'commands': 'RRDD',
            'expected': 0
        },
        # Test case 2: One edit needed (delete first command)
        # S at (0,0), G at (3,3), obstacle at (1,1)
        # Commands: LRRDD (L blocked, need delete)
        {
            'grid': 'S..#.........#..G',
            'commands': 'LRRDD',
            'expected': 1
        },
        # Test case 3: One edit needed (insert command)
        # S at (3,1), G at (1,1), need to go up
        # Commands: L (need to insert U)
        {
            'grid': '....G.#.#.S....#.',
            'commands': 'L',
            'expected': 1
        },
        # Test case 4: Two edits needed
        # S at (0,0), G at (3,3), obstacle pattern
        # Commands: LLLL (completely wrong direction)
        {
            'grid': 'S..#...#...#...G',
            'commands': 'LLLL',
            'expected': 2
        },
        # Test case 5: Already good, no changes
        # Direct path
        {
            'grid': 'S...#...#...#..G',
            'commands': 'RRDD',
            'expected': 0
        }
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, tc in enumerate(test_cases):
        dut._log.info(f"
Running test case {i+1}/{total}")
        
        # Encode grid (16 elements)
        grid_vals = encode_grid(tc['grid'])
        for j in range(16):
            setattr(dut, f'grid[{j}]', grid_vals[j])
        
        # Encode commands
        cmd_encoded, cmd_len = encode_commands(tc['commands'])
        dut.commands.value = cmd_encoded
        dut.cmd_length.value = cmd_len
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 600
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            raise TestFailure(f"Test {i+1}: Timeout - took more than {timeout} cycles")
        
        # Check result
        result = int(dut.min_edits.value)
        expected = tc['expected']
        
        dut._log.info(f"Test {i+1}: Commands='{tc['commands']}', Expected={expected}, Got={result}")
        
        if result == expected:
            dut._log.info(f"Test {i+1}: PASSED")
            passed += 1
        else:
            dut._log.error(f"Test {i+1}: FAILED - Expected {expected}, got {result}")
    
    dut._log.info(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    
    if passed < total:
        raise TestFailure(f"Only {passed}/{total} tests passed")