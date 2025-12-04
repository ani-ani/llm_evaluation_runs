import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_phaser(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        (5, 8, [
            (2,1,4,5), (5,1,12,4), (5,5,9,10), (1,6,4,10), (2,11,7,14)
        ], 4),
        (3, 6, [
            (2,2,3,3), (5,3,6,4), (6,6,7,7)
        ], 3),
        (2, 10, [
            (0,0,5,5), (3,3,8,8)
        ], 2)
    ]
    passed = 0
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for tc_id, (room_count, length, rooms, expected) in enumerate(test_cases):
        # Pack rooms into 40-bit format: {x1[9:0], y1[9:0], x2[9:0], y2[9:0]}
        room_data = 0
        for i, (x1,y1,x2,y2) in enumerate(rooms):
            room_val = (x1 << 30) | (y1 << 20) | (x2 << 10) | y2
            room_data |= room_val << (40*i)
        
        # Apply test case
        dut.room_count.value = room_count
        dut.length.value = length
        for i in range(15):
            dut.rooms_array[i].value = (room_data >> (40*i)) & ((1<<40)-1)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 100 cycles)
        timeout = 100
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        
        assert timeout > 0, "Test case timed out"
        
        # Verify result
        result = dut.max_hits.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"Test case {tc_id} PASSED")
        else:
            dut._log.error(f"Test case {tc_id} FAILED: Expected {expected}, got {result}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
