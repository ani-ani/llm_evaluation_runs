import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_min_phone_calls(dut):
    """Test the min_phone_calls module with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.detector_index.value = 0
    dut.position.value = 0
    dut.call_count.value = 0
    dut.num_detectors.value = 0
    dut.data_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: 3 detectors, 4 houses -> 2 calls
    # Detectors: (3,1), (2,2), (1,1) -> sorted: (1,1), (2,2), (3,1)
    dut._log.info("Test case 1: 3 detectors, expecting result 2")
    await load_detectors(dut, [(1,1), (2,2), (3,1)], 3)
    result = await compute_and_get_result(dut)
    assert result == 2, f"Test 1 failed: expected 2, got {result}"
    dut._log.info("Test case 1 passed")
    
    # Test case 2: 2 detectors, 3 houses -> 23 calls
    # Detectors: (1,23), (2,17) -> sorted: (1,23), (2,17)
    dut._log.info("Test case 2: 2 detectors, expecting result 23")
    await load_detectors(dut, [(1,23), (2,17)], 2)
    result = await compute_and_get_result(dut)
    assert result == 23, f"Test 2 failed: expected 23, got {result}"
    dut._log.info("Test case 2 passed")
    
    # Test case 3: 3 detectors, 9 houses -> 5 calls
    # Detectors: (7,2), (8,3), (3,4) -> sorted: (3,4), (7,2), (8,3)
    dut._log.info("Test case 3: 3 detectors, expecting result 5")
    await load_detectors(dut, [(3,4), (7,2), (8,3)], 3)
    result = await compute_and_get_result(dut)
    assert result == 5, f"Test 3 failed: expected 5, got {result}"
    dut._log.info("Test case 3 passed")
    
    # Edge case: single detector
    dut._log.info("Edge case: single detector (5, 100), expecting result 100")
    await load_detectors(dut, [(5,100)], 1)
    result = await compute_and_get_result(dut)
    assert result == 100, f"Single detector failed: expected 100, got {result}"
    dut._log.info("Single detector test passed")
    
    # Edge case: all overlapping (consecutive positions)
    dut._log.info("Edge case: consecutive detectors, expecting result 10")
    await load_detectors(dut, [(1,5), (2,10), (3,8)], 3)
    result = await compute_and_get_result(dut)
    assert result == 10, f"Consecutive test failed: expected 10, got {result}"
    dut._log.info("Consecutive detectors test passed")
    
    # Edge case: non-overlapping (gaps > 1)
    dut._log.info("Edge case: non-overlapping detectors, expecting result 15")
    await load_detectors(dut, [(1,5), (5,10)], 2)
    result = await compute_and_get_result(dut)
    assert result == 15, f"Non-overlapping test failed: expected 15, got {result}"
    dut._log.info("Non-overlapping test passed")
    
    dut._log.info("All tests passed!")

async def load_detectors(dut, detectors, num_detectors):
    """Load detector data into the module"""
    # Wait for IDLE state
    await RisingEdge(dut.clk)
    
    # Start computation
    dut.start.value = 1
    dut.num_detectors.value = num_detectors
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Load each detector
    for i, (pos, calls) in enumerate(detectors):
        dut.detector_index.value = i
        dut.position.value = pos
        dut.call_count.value = calls
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
        
    dut.data_valid.value = 0

async def compute_and_get_result(dut):
    """Wait for computation to complete and return result"""
    # Wait for done signal with timeout
    cycles = 0
    max_cycles = 50
    
    while cycles < max_cycles:
        await RisingEdge(dut.clk)
        cycles += 1
        if dut.done.value == 1:
            return int(dut.min_calls.value)
    
    raise TestFailure(f"Computation did not complete within {max_cycles} cycles")

# Helper function to run all tests and print summary
if __name__ == "__main__":
    print("Testbench ready for cocotb execution")
