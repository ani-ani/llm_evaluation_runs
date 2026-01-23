import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_door_unlock_solver(dut):
    """Test the door unlock solver (2-SAT) with multiple cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.room_count.value = 0
    dut.switch_count.value = 0
    dut.room_status.value = 0
    for i in range(4):
        setattr(dut, f'switch_room_map_{i}').value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    async def run_test(n, m, room_status_bin, switch_maps, expected_result, name):
        dut._log.info(f"Running test: {name}")
        
        # Set inputs
        dut.room_count.value = n
        dut.switch_count.value = m
        dut.room_status.value = room_status_bin
        
        for i in range(4):
            if i < len(switch_maps):
                getattr(dut, f'switch_room_map_{i}').value = switch_maps[i]
            else:
                getattr(dut, f'switch_room_map_{i}').value = 0
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 1000:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout >= 1000:
                raise TestFailure(f"Test {name} timed out")
        
        # Check result
        if dut.result.value != expected_result:
            raise TestFailure(f"Test {name} failed: Expected {expected_result}, got {dut.result.value}")
        
        dut._log.info(f"Test {name} passed")
        await RisingEdge(dut.clk)
    
    # Test Case 1: Input 3 3
    # 1 0 1
    # 2 1 3
    # 2 1 2
    # 2 2 3
    # Expected: NO
    # Rooms: 1(unlocked), 2(locked), 3(unlocked)
    # S0: {1,3}, S1: {1,2}, S2: {2,3}
    # Room 2 (locked) -> S1, S2: (S1 ^ S2) must be 1
    # Room 1 (unlocked) -> S0, S1: (S0 ^ S1) must be 0
    # Room 3 (unlocked) -> S0, S2: (S0 ^ S2) must be 0
    # This leads to contradiction. Expected 0.
    await run_test(3, 3, 0b00000101, [0b101, 0b011, 0b110], 0, "Case 1 (NO)")
    
    # Test Case 2: Input 3 3
    # 1 0 1
    # 3 1 2 3
    # 1 2
    # 2 1 3
    # Expected: YES
    # Rooms: 1(u), 2(l), 3(u)
    # S0: {1,2,3}, S1: {2}, S2: {1,3}
    # Room 2 (locked) -> S0, S1
    # Room 1 (unlocked) -> S0, S2
    # Room 3 (unlocked) -> S0, S2
    # This works. Expected 1.
    await run_test(3, 3, 0b00000101, [0b111, 0b010, 0b101], 1, "Case 2 (YES)")
    
    # Test Case 3: Input 3 3
    # 1 0 1
    # 3 1 2 3
    # 2 1 2
    # 1 3
    # Expected: NO
    # Rooms: 1(u), 2(l), 3(u)
    # S0: {1,2,3}, S1: {1,2}, S2: {3}
    # Room 2 (locked) -> S0, S1
    # Room 1 (unlocked) -> S0, S1
    # Room 3 (unlocked) -> S0, S2
    # Contradiction. Expected 0.
    await run_test(3, 3, 0b00000101, [0b111, 0b011, 0b100], 0, "Case 3 (NO)")
    
    # Test Case 4: 2 Switches, 1 Room
    # Room locked, S0 and S1 control it. 
    # Need (S0 ^ S1) = 1. Possible. Expected 1.
    await run_test(1, 2, 0b00000000, [0b001, 0b001], 1, "Small Case (YES)")
    
    # Test Case 5: 2 Switches, 1 Room
    # Room unlocked, S0 and S1 control it.
    # Need (S0 ^ S1) = 0. Possible. Expected 1.
    await run_test(1, 2, 0b00000001, [0b001, 0b001], 1, "Small Case (YES)")
