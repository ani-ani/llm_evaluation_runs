import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_magic_square(dut):
    # Clock generator
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test matrices (padded to 4x4)
    test_cases = [
        (2, [[7,12,1,14], [2,13,8,11], [16,3,10,5], [9,6,15,4]], True),  # 4x4 case (size 3=4x4)
        (1, [[2,7,6,0], [9,5,1,0], [4,3,8,0], [0,0,0,0]], True),         # 3x3 valid (mode 2=3x3)
        (1, [[2,7,6,0], [9,5,1,0], [4,3,7,0], [0,0,0,0]], False)        # 3x3 invalid
    ]
    
    passed = 0
    
    for size_mode, matrix, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load matrix
        for i in range(4):
            for j in range(4):
                dut.matrix[i][j].value = int(matrix[i][j])
        
        # Set size (2'b11=4x4, 2'b10=3x3)
        dut.size.value = 2 if size_mode == 2 else 1  # 2=3 for 4x4, 1=2 for 3x3 (coding conflict)
        
        # Start calculation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 16 cycles
        await ClockCycles(dut.clk, 16)
        
        # Check results
        if dut.valid.value == 1:
            if dut.result.value == expected:
                passed += 1
                dut._log.info(f"Passed: size {size_mode}x{size_mode} {'valid' if expected else 'invalid'}")
            else:
                dut._log.error(f"Failed: size {size_mode}x{size_mode} got {dut.result.value}, expected {expected}")
        else:
            dut._log.error(f"Validation failed: valid signal not asserted")
        
        await ClockCycles(dut.clk, 2)  # Padding cycles
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")