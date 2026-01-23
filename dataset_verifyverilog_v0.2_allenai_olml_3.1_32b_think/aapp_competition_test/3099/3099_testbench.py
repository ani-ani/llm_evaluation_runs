import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_spy_network_basic(dut):
    """Test spy network with basic case"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: 4 spies, 1 enemy (spy 1), 3 connections
    # Graph: 0->1, 1->2, 2->3
    # Enemies: 1
    # Expected: 2 (message 0 privately, 2 publicly reaches 2,3)
    dut.num_spies.value = 4
    dut.enemy_mask.value = 0b00000010  # spy 1 is enemy
    
    # Adjacency matrix
    dut.adj_matrix[0].value = 0b00000000  # no outgoing from 0 to others
    dut.adj_matrix[1].value = 0b00000000  # but 1 is enemy, ignore
    dut.adj_matrix[2].value = 0b00000000
    dut.adj_matrix[3].value = 0b00000000
    # Actually, need to set connections properly
    # adj_matrix[i] should have bit j set if i->j exists
    dut.adj_matrix[0].value = 0b00000010  # 0->1
    dut.adj_matrix[1].value = 0b00000100  # 1->2
    dut.adj_matrix[2].value = 0b00001000  # 2->3
    dut.adj_matrix[3].value = 0b00000000
    dut.adj_matrix[4].value = 0b00000000
    dut.adj_matrix[5].value = 0b00000000
    dut.adj_matrix[6].value = 0b00000000
    dut.adj_matrix[7].value = 0b00000000
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Test timed out")
    
    if dut.min_messages.value != 2:
        raise TestFailure(f"Expected 2, got {int(dut.min_messages.value)}")
    
    print("Test 1 passed: Got 2 messages as expected")

@cocotb.test()
async def test_spy_network_no_enemies(dut):
    """Test with no enemies"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2: 4 spies, 0 enemies
    # Graph: 0->2, 0->1, 2->1, 2->3
    # Expected: 1 (public to 0 reaches all)
    dut.num_spies.value = 4
    dut.enemy_mask.value = 0
    
    dut.adj_matrix[0].value = 0b00000110  # 0->1, 0->2
    dut.adj_matrix[1].value = 0b00000000
    dut.adj_matrix[2].value = 0b00001010  # 2->1, 2->3
    dut.adj_matrix[3].value = 0b00000000
    dut.adj_matrix[4].value = 0b00000000
    dut.adj_matrix[5].value = 0b00000000
    dut.adj_matrix[6].value = 0b00000000
    dut.adj_matrix[7].value = 0b00000000
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Test timed out")
    
    if dut.min_messages.value != 1:
        raise TestFailure(f"Expected 1, got {int(dut.min_messages.value)}")
    
    print("Test 2 passed: Got 1 message as expected")

@cocotb.test()
async def test_spy_network_multiple_enemies(dut):
    """Test with multiple enemies"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 3: 4 spies, 2 enemies (1,2)
    # Graph: 0->1, 0->2, 0->3, 1->3, 2->3
    # Expected: 2 (can't use public from 0 as it reaches enemies)
    # So need private to 0 and 3? But 3 can be reached from 0 through 1,2 but they're enemies
    # Actually, we can private message 0 and 3: 2 messages
    dut.num_spies.value = 4
    dut.enemy_mask.value = 0b00000110  # spies 1 and 2 are enemies
    
    dut.adj_matrix[0].value = 0b00001110  # 0->1, 0->2, 0->3
    dut.adj_matrix[1].value = 0b00001000  # 1->3
    dut.adj_matrix[2].value = 0b00001000  # 2->3
    dut.adj_matrix[3].value = 0b00000000
    dut.adj_matrix[4].value = 0b00000000
    dut.adj_matrix[5].value = 0b00000000
    dut.adj_matrix[6].value = 0b00000000
    dut.adj_matrix[7].value = 0b00000000
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Test timed out")
    
    if dut.min_messages.value != 2:
        raise TestFailure(f"Expected 2, got {int(dut.min_messages.value)}")
    
    print("Test 3 passed: Got 2 messages as expected")

@cocotb.test()
async def test_spy_network_single_safe(dut):
    """Test with single non-enemy spy"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Only spy 0 is safe, others are enemies
    dut.num_spies.value = 4
    dut.enemy_mask.value = 0b00001110
    
    dut.adj_matrix[0].value = 0b00000000
    dut.adj_matrix[1].value = 0b00000000
    dut.adj_matrix[2].value = 0b00000000
    dut.adj_matrix[3].value = 0b00000000
    dut.adj_matrix[4].value = 0b00000000
    dut.adj_matrix[5].value = 0b00000000
    dut.adj_matrix[6].value = 0b00000000
    dut.adj_matrix[7].value = 0b00000000
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Test timed out")
    
    if dut.min_messages.value != 1:
        raise TestFailure(f"Expected 1, got {int(dut.min_messages.value)}")
    
    print("Test 4 passed: Got 1 message as expected")

@cocotb.test()
async def test_spy_network_no_spies(dut):
    """Test edge case: all spies are enemies"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # All spies are enemies
    dut.num_spies.value = 3
    dut.enemy_mask.value = 0b00000111
    
    dut.adj_matrix[0].value = 0b00000000
    dut.adj_matrix[1].value = 0b00000000
    dut.adj_matrix[2].value = 0b00000000
    dut.adj_matrix[3].value = 0b00000000
    dut.adj_matrix[4].value = 0b00000000
    dut.adj_matrix[5].value = 0b00000000
    dut.adj_matrix[6].value = 0b00000000
    dut.adj_matrix[7].value = 0b00000000
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Test timed out")
    
    if dut.min_messages.value != 0:
        raise TestFailure(f"Expected 0, got {int(dut.min_messages.value)}")
    
    print("Test 5 passed: Got 0 messages as expected")
    print(f"
Summary: All tests passed!")
