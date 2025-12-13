import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
from cocotb.binary import BinaryValue
import numpy as np

@cocotb.test()
async def test_gcd_distinct(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (n, sequence, expected_count)
    tests = [
        (4, [9,6,2,4,0,0,0,0], 6),
        (4, [9,6,3,4,0,0,0,0], 5),
        (3, [15,30,15,0,0,0,0,0], 3),
        (1, [12345,0,0,0,0,0,0,0], 1)
    ]
    
    passed = 0
    dut._log.info("Starting GCD distinct count tests")
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for idx, (test_n, test_seq, expected) in enumerate(tests):
        dut._log.info(f"Running test #{idx+1}: {test_seq[:test_n]}")
        
        # Load inputs
        dut.n.value = test_n
        for i in range(8):
            dut.a[i].value = test_seq[i] if i < len(test_seq) else 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 256 cycles)
        timeout = 256 + 10
        while not dut.done.value:
            await RisingEdge(dut.clk)
            timeout -= 1
            if timeout == 0:
                dut._log.error("Test timed out")
                break
        
        # Verify output
        await Timer(5, units='ns')
        if dut.count.value == expected:
            dut._log.info(f"Test #{idx+1} passed: got {dut.count.value}")
            passed += 1
        else:
            dut._log.error(f"Test #{idx+1} failed: expected {expected}, got {dut.count.value}")
    
    dut._log.info(f"Summary: {passed}/{len(tests)} tests passed")
    assert passed == len(tests), "Some tests failed"