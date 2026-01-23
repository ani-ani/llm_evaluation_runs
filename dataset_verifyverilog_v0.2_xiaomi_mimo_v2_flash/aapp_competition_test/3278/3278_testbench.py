import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure

def pack_frog(pos, dist):
    """Pack frog position and distance into 16-bit value"""
    return (pos << 8) | dist

def check_frog_at_position(frog_pos, frog_dist, target_pos):
    """Check if frog can reach target position"""
    if target_pos < frog_pos:
        return False
    diff = target_pos - frog_pos
    return diff % frog_dist == 0

def find_max_tower(frogs, max_pos=256):
    """Find maximum tower size and smallest position"""
    best_pos = 0
    max_size = 0
    
    for pos in range(max_pos):
        count = 0
        for f_pos, f_dist in frogs:
            if check_frog_at_position(f_pos, f_dist, pos):
                count += 1
        
        if count > max_size or (count == max_size and pos < best_pos):
            max_size = count
            best_pos = pos
    
    return best_pos, max_size

@cocotb.test()
async def test_frog_tower_basic(dut):
    """Test basic frog tower detection"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.frog_count.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: 3 frogs
    # Frog 1: pos=0, dist=2
    # Frog 2: pos=1, dist=2  
    # Frog 3: pos=3, dist=3
    frogs = [(0, 2), (1, 2), (3, 3)]
    expected_pos, expected_size = find_max_tower(frogs)
    
    # Load frogs
    dut.frog_count.value = 3
    for i, (pos, dist) in enumerate(frogs):
        dut.frog_data[i].value = pack_frog(pos, dist)
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 2000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Timeout waiting for done")
    
    # Check results
    actual_pos = int(dut.tower_position.value)
    actual_size = int(dut.tower_size.value)
    
    print(f"Test 1: Expected pos={expected_pos}, size={expected_size}")
    print(f"Test 1: Actual pos={actual_pos}, size={actual_size}")
    
    assert actual_pos == expected_pos, f"Position mismatch: expected {expected_pos}, got {actual_pos}"
    assert actual_size == expected_size, f"Size mismatch: expected {expected_size}, got {actual_size}"
    
    print("Test 1 passed!")

@cocotb.test()
async def test_frog_tower_case2(dut):
    """Test second example case"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.frog_count.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: 5 frogs
    frogs = [(0, 2), (1, 3), (3, 3), (7, 5), (9, 5)]
    expected_pos, expected_size = find_max_tower(frogs)
    
    dut.frog_count.value = 5
    for i, (pos, dist) in enumerate(frogs):
        dut.frog_data[i].value = pack_frog(pos, dist)
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 2000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Timeout")
    
    actual_pos = int(dut.tower_position.value)
    actual_size = int(dut.tower_size.value)
    
    print(f"Test 2: Expected pos={expected_pos}, size={expected_size}")
    print(f"Test 2: Actual pos={actual_pos}, size={actual_size}")
    
    assert actual_pos == expected_pos
    assert actual_size expected_size

    print("Test 2 passed!")

@cocotb.test()
async def test_frog_tower_edge(dut):
    """Test edge cases"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.frog_count.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Single frog at pos 100, dist 7
    frogs = [(100, 7)]
    expected_pos, expected_size = find_max_tower(frogs)
    
    dut.frog_count.value = 1
    dut.frog_data[0].value = pack_frog(100, 7)
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 2000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Timeout")
    
    actual_pos = int(dut.tower_position.value)
    actual_size = int(dut.tower_size.value)
    
    assert actual_pos == expected_pos
    assert actual_size == 1
    
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Two frogs at same position
    frogs = [(5, 2), (5, 3)]
    expected_pos, expected_size = find_max_tower(frogs)
    
    dut.frog_count.value = 2
    dut.frog_data[0].value = pack_frog(5, 2)
    dut.frog_data[1].value = pack_frog(5, 3)
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Timeout")
    
    actual_pos = int(dut.tower_position.value)
    actual_size = int(dut.tower_size.value)
    
    print(f"Test 3: Expected pos={expected_pos}, size={expected_size}")
    print(f"Test 3: Actual pos={actual_pos}, size={actual_size}")
    
    assert actual_pos == expected_pos
    assert actual_size == 2
    print("Test 3 passed!")

@cocotb.test()
async def test_frog_tower_random(dut):
    """Test with random frogs to verify logic"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.frog_count.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    frogs = [(10, 2), (11, 3), (20, 5), (25, 5)]
    expected_pos, expected_size = find_max_tower(frogs)
    
    dut.frog_count.value = 4
    for i, (pos, dist) in enumerate(frogs):
        dut.frog_data[i].value = pack_frog(pos, dist)
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 2000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    else:
        raise TestFailure("Timeout")
    
    actual_pos = int(dut.tower_position.value)
    actual_size = int(dut.tower_size.value)
    
    print(f"Test 4: Expected pos={expected_pos}, size={expected_size}")
    print(f"Test 4: Actual pos={actual_pos}, size={actual_size}")
    
    assert actual_pos == expected_pos
    assert actual_size == expected_size
    
    print("
=== Summary ===")
    print("All tests completed successfully")
    print(f"Final Result: Position={actual_pos}, Size={actual_size}")
}