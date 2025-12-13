import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import itertools
import random

@cocotb.test()
async def test_danger_detector(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    def load_point(x, y, is_castle):
        dut.x_i.value = int(x)
        dut.y_i.value = int(y)
        dut.is_castle_i.value = 1 if is_castle else 0
        dut.load.value = 1
        await RisingEdge(dut.clk)
        dut.load.value = 0
    
    async def reset():
        dut.rst_n.value = 0
        dut.start.value = 0
        dut.load.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    def is_collinear(p1, p2, p3):
        return (p2[0]-p1[0])*(p3[1]-p1[1]) == (p3[0]-p1[0])*(p2[1]-p1[1])
    
    test_cases = [
        { # Sample 1: Nazi troops (4), Castles (9→4) → Output=4
          'nazis': [(0,1), (3,7), (4,5), (6,5)],
          'castles': [(1,4), (1,6), (2,3), (2,5)], # Only first 4 castles used
          'expected': 3  # Actually in danger from sample description (4→3 since we scaled S=4)
        },
        { # Sample 2: Degenerate quadrilateral, output=0
          'nazis': [(1,2), (3,2), (5,2), (2,5)],
          'castles': [(3,4),(2,3)],  # Scaled S=2 → max 4 in new design
          'expected': 0
        },
        { # Added test case
          'nazis': [(0,0),(0,10),(10,0),(10,10),(5,5)],
          'castles': [(1,1),(5,5),(9,9),(3,7)],
          'expected': 3 # [(1,1) inside, (5,5) on border, (9,9) inside]
        }
    ]
    
    await reset()
    
    for tc in test_cases:
        dut._log.info(f"Testing case {tc}")
        # Load nazis
        for x,y in tc['nazis']:
            await load_point(x,y,False)
        # Load castles (max 4)
        for x,y in tc['castles'][:4]: # Only load up to 4 castles
            await load_point(x,y,True)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        actual = dut.danger_count.value
        assert actual == tc['expected'], f"Expected {tc['expected']}, got {actual}"
        
        # Reset for next test case
        dut.rst_n.value = 0
        await reset()
    
    dut._log.info("3/3 tests passed")