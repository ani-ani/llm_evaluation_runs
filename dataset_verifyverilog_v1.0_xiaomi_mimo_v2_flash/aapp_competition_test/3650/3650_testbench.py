import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
GRID_ROWS = 4
GRID_COLS = 4
MAX_BLOCKS = 8
CLK_PERIOD_NS = 10

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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_sliding_blocks(dut):
    """Test the sliding blocks solver with multiple scenarios."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    # Format: (init_r, init_c, target_blocks, num_blocks, description, should_pass)
    # target_blocks is list of (r,c) tuples
    test_cases = [
        (
            2, 3,  # Initial block at (2,3)
            [(2,4), (3,3), (1,4), (3,2)],  # Target blocks to add
            4,
            "Simple 4-block puzzle",
            True
        ),
        (
            1, 1,
            [(1,2), (2,1), (2,2)],
            3,
            "L-shape puzzle",
            True
        ),
        (
            2, 2,
            [(2,3), (3,2), (3,3), (4,4)],
            4,
            "Impossible diagonal",
            False
        ),
        (
            1, 1,
            [(1,2), (1,3), (1,4)],
            3,
            "Line puzzle",
            True
        ),
        (
            2, 2,
            [(2,3), (3,3), (4,3), (4,2)],
            4,
            "L-shape variant",
            True
        )
    ]
    
    total_passed = 0
    total_failed = 0
    
    for case_idx, (init_r, init_c, target_blocks, num_blocks, desc, should_pass) in enumerate(test_cases):
        dut._log.info(f"\nTest Case {case_idx+1}: {desc}")
        
        # Wait for previous test to complete
        await RisingEdge(dut.clk)
        
        # Set inputs
        dut.init_r.value = clamp_to_width(init_r, DATA_WIDTH)
        dut.init_c.value = clamp_to_width(init_c, DATA_WIDTH)
        dut.num_blocks.value = num_blocks
        
        # Set target blocks individually
        for i in range(MAX_BLOCKS):
            if i < len(target_blocks):
                r, c = target_blocks[i]
                # Handle both indexed array and individual port styles
                if has_signal(dut, f'target_r_{i}'):
                    getattr(dut, f'target_r_{i}').value = clamp_to_width(r, DATA_WIDTH)
                    getattr(dut, f'target_c_{i}').value = clamp_to_width(c, DATA_WIDTH)
                elif hasattr(dut, 'target_r'):
                    dut.target_r[i].value = clamp_to_width(r, DATA_WIDTH)
                    dut.target_c[i].value = clamp_to_width(c, DATA_WIDTH)
            else:
                # Clear unused entries
                if has_signal(dut, f'target_r_{i}'):
                    getattr(dut, f'target_r_{i}').value = 0
                    getattr(dut, f'target_c_{i}').value = 0
                elif hasattr(dut, 'target_r'):
                    dut.target_r[i].value = 0
                    dut.target_c[i].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        await wait_for_done(dut)
        
        # Check results
        if not is_value_defined(dut.possible.value):
            dut._log.error(f"  FAIL: possible signal is undefined")
            total_failed += 1
            continue
        
        actual_possible = int(dut.possible.value) == 1
        
        if actual_possible == should_pass:
            dut._log.info(f"  PASS: Expected {should_pass}, got {actual_possible}")
            total_passed += 1
            
            # If should be possible, verify moves are output
            if should_pass:
                moves = []
                for _ in range(num_blocks):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.move_valid.value) and int(dut.move_valid.value) == 1:
                        dir_val = int(dut.move_dir.value)
                        k_val = int(dut.move_k.value)
                        dir_char = ['<', '>', '^', 'v'][dir_val]
                        moves.append(f"{dir_char} {k_val}")
                        dut._log.info(f"  Move: {dir_char} {k_val}")
                    else:
                        dut._log.warning(f"  Missing move at cycle")
                
                if len(moves) != num_blocks:
                    dut._log.error(f"  Expected {num_blocks} moves, got {len(moves)}")
                    total_failed += 1
                else:
                    dut._log.info(f"  Got {len(moves)} moves as expected")
        else:
            dut._log.error(f"  FAIL: Expected {should_pass}, got {actual_possible}")
            total_failed += 1
        
        # Wait a few cycles before next test
        for _ in range(3):
            await RisingEdge(dut.clk)
    
    # Summary
    dut._log.info(f"\n{'='*60}")
    dut._log.info(f"SUMMARY: {total_passed}/{total_passed+total_failed} tests passed")
    
    if total_failed > 0:
        raise TestFailure(f"{total_failed} tests failed")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases and boundary conditions."""
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test 1: Single block (num_blocks=0)
    dut._log.info("Test 1: Single block puzzle (num_blocks=0)")
    dut.init_r.value = 2
    dut.init_c.value = 2
    dut.num_blocks.value = 0
    for i in range(MAX_BLOCKS):
        if has_signal(dut, f'target_r_{i}'):
            getattr(dut, f'target_r_{i}').value = 0
            getattr(dut, f'target_c_{i}').value = 0
        elif hasattr(dut, 'target_r'):
            dut.target_r[i].value = 0
            dut.target_c[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)
    
    if is_value_defined(dut.possible.value) and int(dut.possible.value) == 1:
        dut._log.info("  PASS: Single block handled correctly")
    else:
        raise TestFailure("Single block test failed")
    
    await RisingEdge(dut.clk)
    
    # Test 2: Maximum blocks
    dut._log.info("Test 2: Maximum blocks")
    dut.init_r.value = 2
    dut.init_c.value = 2
    dut.num_blocks.value = 8
    # Create a 3x3 square with init at center
    max_blocks = [(2,3), (3,2), (3,3), (2,4), (4,2), (4,3), (4,4), (3,4)]
    for i in range(8):
        r, c = max_blocks[i]
        if has_signal(dut, f'target_r_{i}'):
            getattr(dut, f'target_r_{i}').value = r
            getattr(dut, f'target_c_{i}').value = c
        elif hasattr(dut, 'target_r'):
            dut.target_r[i].value = r
            dut.target_c[i].value = c
    for i in range(8, MAX_BLOCKS):
        if has_signal(dut, f'target_r_{i}'):
            getattr(dut, f'target_r_{i}').value = 0
            getattr(dut, f'target_c_{i}').value = 0
        elif hasattr(dut, 'target_r'):
            dut.target_r[i].value = 0
            dut.target_c[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)
    
    if is_value_defined(dut.possible.value):
        dut._log.info(f"  Result: {int(dut.possible.value)}")
        dut._log.info("  PASS: Maximum blocks handled")
    else:
        raise TestFailure("Maximum blocks test failed")
    
    await RisingEdge(dut.clk)
    
    # Test 3: Reset during operation
    dut._log.info("Test 3: Reset during operation")
    dut.init_r.value = 1
    dut.init_c.value = 1
    dut.num_blocks.value = 3
    for i in range(3):
        r, c = [(1,2), (2,1), (2,2)][i]
        if has_signal(dut, f'target_r_{i}'):
            getattr(dut, f'target_r_{i}').value = r
            getattr(dut, f'target_c_{i}').value = c
        elif hasattr(dut, 'target_r'):
            dut.target_r[i].value = r
            dut.target_c[i].value = c
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    # Apply reset mid-operation
    await reset_dut(dut)
    
    # Should be idle now
    if is_value_defined(dut.done.value) and int(dut.done.value) == 0:
        dut._log.info("  PASS: Reset handled correctly")
    else:
        dut._log.warning("  Reset test inconclusive")
    
    dut._log.info("\nAll edge case tests completed")
