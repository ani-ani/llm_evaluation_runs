import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.utils import get_sim_time
import random

@cocotb.test()
async def test_playlist(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset procedure
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        {  # Test case 1: Valid path exists (Sample Input 1 adapted)
            "max_songs": 10,
            "artist_ids": [0,1,2,3,4,5,6,7,8,9] + [0]*6,
            "t_counts": [2,1,2,1,1,1,2,0,1,1] + [0]*6,
            "next_ids": [
                [9, 2, 0, 0],   # Song 0 (a): 10,3 → 9,2 (0-indexed)
                [5, 0, 0, 0],   # Song 1 (b): 6 → 5
                [0,4,0,0],      # Song 2 (c): 1,5 → 0,4
                [8, 0,0,0],     # Song 3 (d): 9 → 8
                [3,0,0,0],      # Song 4 (e):4 → 3
                [1,0,0,0],      # Song 5 (f):2 →1
                [5,7,0,0],      # Song 6 (g):6,8 →5,7
                [0]*4,          # Song 7 (h):0
                [2,0,0,0],      # Song 8 (i):3 →2
                [6,0,0,0]       # Song 9 (j):7 →6
            ] + [[0]*4]*6,
            "expected": [4,3,8,2,0,9,6,5,1],  # 5,4,9,3,1,10,7,6,2 0-indexed
            "should_fail": False
        },
        {  # Test case 2: Duplicate artist (Sample Input 2 adapted)
            "max_songs": 10,
            "artist_ids": [0,0,2,3,4,5,6,7,8,9] + [0]*6,
            "t_counts": [2,1,2,1,1,1,2,0,1,1] + [0]*6,
            "next_ids": [
                [9,2,0,0], [5,0,0,0], [0,4,0,0], [8,0,0,0], [3,0,0,0],
                [1,0,0,0], [5,7,0,0], [0]*4, [2,0,0,0], [6,0,0,0]
            ] + [[0]*4]*6,
            "expected": [],
            "should_fail": True
        }
    ]
    
    passed = 0
    for case in test_cases:
        # Load test data
        dut.max_songs.value = case["max_songs"]
        for i in range(16):
            dut.artist_ids[i].value = case["artist_ids"][i]
            dut.t_counts[i].value = case["t_counts"][i]
            for j in range(4):
                dut.next_ids[i][j].value = case["next_ids"][i][j]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check results
        if case["should_fail"]:
            if dut.found.value == 0:
                passed += 1
            else:
                dut._log.error("Test failed: Expected 'fail' but found path")
        else:
            if dut.found.value == 1:
                playlist = [dut.playlist[i].value.integer for i in range(9)]
                if playlist == case["expected"]:
                    passed += 1
                else:
                    dut._log.error(f"Playlist mismatch: Got {playlist}, Expected {case['expected']}")
            else:
                dut._log.error("Test failed: Valid path exists but not found")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
