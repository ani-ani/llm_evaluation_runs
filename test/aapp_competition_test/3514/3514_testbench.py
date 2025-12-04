import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_max_bombs(dut):
    # Create clock generator
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    # Reset sequence
    dut.rst_n.value = 0
    await Timer(15, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        (0b00000000_00100000_00000100_00000000_00000000_00000000_00000000_00000001, 2),  # 3x3 grid
        (0b00000000_01100000_10000000_10000001, 3),  # 3x4 grid
        (0xFFFFFFFFFFFFFFFF, 0),  # All disarmed (should output 0)
        (0xFFFF0000FFFF0000, 16),  # Full 8x8 chessboard (max_count=16)
        (0b00000001_00000010_00000100_00001000_00010000_00100000_01000000_10000000, 1)  # Diagonal (max=7)
    ]
    
    passed = 0
    for i, (grid, expected) in enumerate(test_cases):
        dut.start.value = 0
        dut.grid_data.value = grid
        await RisingEdge(dut.clk)
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 2 cycles for result
        for _ in range(2):
            await RisingEdge(dut.clk)
            
        # Check result
        if dut.done.value == 1 and dut.max_count.value == expected:
            passed += 1
            dut._log.info(f"Test {i} passed: {dut.max_count.value} == {expected}")
        else:
            dut._log.error(f"Test {i} FAILED: got {dut.max_count.value}, expected {expected} for grid 0x{grid:016X}")
    
    dut._log.info(f"
Test summary: {passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), "Some tests failed"