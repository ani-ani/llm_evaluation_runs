import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_room_equiv(dut):
    # Generate 50MHz clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    await RisingEdge(dut.clk)
    
    # Test Case 1 (2 equivalence sets)
    test1 = {
        "room_count": 6,
        "rooms": [
            [2, 2,4,0],  # Room 1: 2 exits to 2,4
            [3,1,3,5],   # Room 2
            [2,2,4,0],   # Room 3
            [3,1,3,6],   # Room 4
            [2,2,6,0],   # Room 5
            [2,4,5,0],   # Room 6
            [0,0,0,0],   # Unused
            [0,0,0,0]    # Unused
        ]
    }
    expected1 = [[2,4], [5,6]]
    
    # Test Case 2 (no non-singleton sets)
    test2 = {
        "room_count": 3,
        "rooms": [
            [1,2,0,0],  # Room 1
            [1,1,0,0],  # Room 2
            [1,1,0,0],  # Room 3
            [0,0,0,0],  # ... remainder unused
            [0,0,0,0],
            [0,0,0,0],
            [0,0,0,0],
            [0,0,0,0]
        ]
    }
    expected2 = []
    
    all_tests = [(test1, expected1), (test2, expected2)]
    passed = 0
    
    for test_data, expected in all_tests:
        # Reset
        dut.rst_n.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.room_count.value = test_data["room_count"]
        for i in range(8):
            for j in range(4):
                idx = i*4 + j
                dut.rooms.value = (test_data["rooms"][i][j] & 0x7) | ((j < test_data["rooms"][i][0]) << 3)
            await RisingEdge(dut.clk)
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        await ClockCycles(dut.clk, 18)
        
        # Verify results
        if not dut.done.value:
            dut._log.error("Done signal not asserted!")
            continue
        
        # Extract sets
        sets = []
        curr_set = []
        for i in range(8):
            room = dut.equivalent_sets[i].value
            if room == 0:  # padding
                if curr_set:
                    sets.append(sorted(curr_set))
                    curr_set = []
                continue
            curr_set.append(int(room))
        
        # Compare with expected
        if sets == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed. Got {sets}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(all_tests)} tests passed")