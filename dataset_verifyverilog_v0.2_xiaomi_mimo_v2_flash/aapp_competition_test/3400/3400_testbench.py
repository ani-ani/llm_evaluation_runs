import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

async def write_input(dut, data):
    dut.din_valid.value = 1
    dut.din_end.value = 0
    for i, byte in enumerate(data):
        dut.din.value = byte
        await RisingEdge(dut.clk)
        if i == len(data) - 1:
            dut.din_end.value = 1
    dut.din_valid.value = 0
    dut.din_end.value = 0

@cocotb.test()
async def test_wonderland_basic(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.din_valid.value = 0
    dut.din_end.value = 0
    dut.din.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: From problem description (Scaled down)
    # Input: 3 1 3 3
    # 3 4 1 2 3 2
    # 4 3 1 2 1
    # 1 4 1 2 1 3
    
    # We need to feed bytes. Header is 4 integers. 
    # For simplicity in this test, we assume the DUT parses byte stream correctly.
    # Let's provide raw bytes for the test case.
    # Header: 3 1 3 3 -> [3, 1, 3, 3]
    # Trip 1: 3 4 1 2 3 2 -> [3, 4, 1, 2, 3, 2]
    # Trip 2: 4 3 1 2 1 -> [4, 3, 1, 2, 1]
    # Trip 3: 1 4 1 2 1 3 -> [1, 4, 1, 2, 1, 3]
    
    input_data = [
        3, 1, 3, 3,
        3, 4, 1, 2, 3, 2,
        4, 3, 1, 2, 1,
        1, 4, 1, 2, 1, 3
    ]
    
    dut._log.info("Starting test case 1")
    cocotb.start_soon(write_input(dut, input_data))
    
    # Wait for processing
    # The processing takes many cycles. We just poll done.
    timeout = 0
    while not dut.result_valid.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 10000:
        raise TestFailure("Timeout waiting for result")
        
    # Expected output: 9
    result = int(dut.result.value)
    dut._log.info(f"Result: {result}")
    if result != 9:
        raise TestFailure(f"Expected 9, got {result}")
        
    await RisingEdge(dut.clk)
    # Wait for ready
    while not dut.ready.value:
        await RisingEdge(dut.clk)
        
    # Test Case 2: Second example
    # Input: 5 5 1 9
    # ... data ...
    # Expected output: 6
    
    input_data_2 = [
        5, 5, 1, 9,
        0, 3, 1, 2, 3,
        1, 4, 1, 4, 2, 3,
        6, 4, 3, 4, 1, 3,
        11, 5, 1, 3, 4, 2, 1,
        4, 4, 1, 2, 4, 1,
        6, 6, 1, 2, 3, 1, 4, 3,
        7, 4, 2, 3, 4, 1,
        11, 3, 4, 3, 5,
        12, 5, 5, 2, 4, 2, 5
    ]
    
    dut._log.info("Starting test case 2")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cocotb.start_soon(write_input(dut, input_data_2))
    
    timeout = 0
    while not dut.result_valid.value and timeout < 20000:
        await RisingEdge(dut.clk)
        timeout += 1
        
    if timeout >= 20000:
        raise TestFailure("Timeout waiting for result")
        
    result = int(dut.result.value)
    dut._log.info(f"Result: {result}")
    if result != 6:
        raise TestFailure(f"Expected 6, got {result}")
