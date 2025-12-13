import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_grasshopper(dut):
    # Generate 50MHz clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
    
    # Test cases (scaled petal counts < 65535)
    test_cases = [
        {
            "grid": [1,2,3,4, 2,3,4,5, 3,4,5,6, 4,5,6,7],
            "init": (0,0),  # Row/Col 0-based 4x4 grid
            "expected": 4
        },
        {
            "grid": [20,16,25,17, 11,13,13,30, 15,29,10,26, 27,19,14,24],
            "init": (2,2),
            "expected": 5  # Adjusted expected value for smaller grid
        },
        {
            "grid": [9]*16,  # All same petal counts
            "init": (1,1),
            "expected": 1  # Cannot move
        }
    ]
    
    passed = 0
    total = len(test_cases)
    
    for tc in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load grid data
        for i in range(16):
            dut.grid[i].value = tc["grid"][i]
        
        # Set initial position
        dut.init_row.value = tc["init"][0]
        dut.init_col.value = tc["init"][1]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (timeout after 200 cycles)
        timeout = 200
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        
        if timeout == 0:
            dut._log.error("Test timed out")
        else:
            if dut.max_flowers.value == tc["expected"]:
                passed += 1
            else:
                dut._log.error(f"Test failed. Expected {tc['expected']}, got {dut.max_flowers.value}")
    
    dut._log.info(f"{passed}/{total} tests passed")
