import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_packman(dut):
    # Create 16MHz clock
    clock = Clock(dut.clk, 62, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (converted to 16-bit representations): 
    # Format: (game_field, expected_time, description) 
    test_cases = [
        (0b1001001010000000, 3, "Original test 1 scaled"),
        (0b0110001101000000, 2, "Original test 2 scaled"),
        (0b0001000000100000, 1, "Single Packman right case"),
        (0b0010000000000100, 1, "Single Packman left case"),
        (0b1010010000100100, 3, "Complex pattern")
    ]
    
    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    for field, expected, desc in test_cases:
        dut.game_field.value = field
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for computation (6 cycles)
        for _ in range(10):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        result = dut.min_time.value.integer
        if result == expected:
            passed += 1
            dut._log.info(f"TC '{desc}' passed: {result}")
        else:
            dut._log.error(f"Test FAILED: {desc}
  Expected: {expected}, Got: {result}
  Field: {bin(field)}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)