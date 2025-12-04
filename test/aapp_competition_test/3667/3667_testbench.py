import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

# Q12.4 conversion helper
def to_q12_4(val):
    return int(val * 16) & 0xFFFF

@cocotb.test()
async def test_pipe_cleaner(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test case 1: Impossible (3 pipes forming triangle)
    test1 = {
        "num_wells": 3,
        "num_pipes": 3,
        "well_x": [to_q12_4(0), to_q12_4(0), to_q12_4(2)],
        "well_y": [to_q12_4(0), to_q12_4(2), to_q12_4(0)],
        "pipe_start": [0, 1, 2],  # Well indices (0-based)
        "pipe_end_x": [to_q12_4(2), to_q12_4(2), to_q12_4(0)],
        "pipe_end_y": [to_q12_4(3), to_q12_4(2), to_q12_4(3)]
    }
    
    # Test case 2: Possible (no intersections)
    test2 = {
        "num_wells": 2,
        "num_pipes": 2,
        "well_x": [to_q12_4(0), to_q12_4(0)],
        "well_y": [to_q12_4(0), to_q12_4(10)],
        "pipe_start": [0, 0],
        "pipe_end_x": [to_q12_4(5), to_q12_4(2)],
        "pipe_end_y": [to_q12_4(15), to_q12_4(15)]
    }
    
    tests = [
        (test1, 0),  # Expected impossible
        (test2, 1)   # Expected possible
    ]
    
    passed = 0
    for test_data, expected in tests:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.num_wells.value = test_data["num_wells"]
        dut.num_pipes.value = test_data["num_pipes"]
        for i in range(8):
            dut.well_x[i].value = test_data["well_x"][i] if i < len(test_data["well_x"]) else 0
            dut.well_y[i].value = test_data["well_y"][i] if i < len(test_data["well_y"]) else 0
            dut.pipe_start[i].value = test_data["pipe_start"][i] if i < len(test_data["pipe_start"]) else 0
            dut.pipe_end_x[i].value = test_data["pipe_end_x"][i] if i < len(test_data["pipe_end_x"]) else 0
            dut.pipe_end_y[i].value = test_data["pipe_end_y"][i] if i < len(test_data["pipe_end_y"]) else 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 300
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        
        if timeout == 0:
            dut._log.error("Test timed out")
        else:
            if dut.result.value == expected:
                passed += 1
                dut._log.info(f"Test passed. Received {'possible' if dut.result.value else 'impossible'}")
            else:
                dut._log.error(f"Test failed. Expected {'possible' if expected else 'impossible'} got {'possible' if dut.result.value else 'impossible'}")
    
    dut._log.info(f"{passed}/{len(tests)} tests passed")
    assert passed == len(tests)