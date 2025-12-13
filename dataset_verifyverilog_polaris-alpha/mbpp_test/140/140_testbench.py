import cocotb
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_flattener(dut):
    # Generate 100MHz clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    test_cases = [
        ([[3,4,5], [4,5,7], [1,4,0]], {3,4,5,7,1}),
        ([[1,2,3], [4,2,3], [7,8,0]], {1,2,3,4,7,8}),
        ([[7,8,9], [10,11,12], [10,11,0]], {7,8,9,10,11,12}),
        ([[1,1,1], [2,2,2], [3,3,3]], {1,2,3}),
        ([[5,5,5], [5,5,5], [5,5,5]], {5})
    ]
    
    passed = 0
    
    for input_data, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Flatten input to 3x3 array
        for i in range(3):
            for j in range(3):
                dut.list_data[i][j].value = input_data[i][j] if j < len(input_data[i]) else 0
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 9 cycles
        for _ in range(9):
            await RisingEdge(dut.clk)
        
        # Verify completion
        if dut.done.value != 1:
            dut._log.error(f"Test failed: Done not asserted after 9 cycles")
            continue
        
        # Collect unique outputs
        result_set = set()
        for i in range(int(dut.unique_count.value)):
            result_set.add(int(dut.unique_array[i].value))
        
        # Compare with expected
        if result_set == expected:
            dut._log.info(f"PASS: Input {input_data} => {result_set}")
            passed += 1
        else:
            dut._log.error(f"FAIL: Input {input_data} => {result_set}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")