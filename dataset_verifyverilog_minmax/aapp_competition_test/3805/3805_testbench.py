import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

@cocotb.test()
async def test_wire_untangle(dut):
    # Test cases (input, expected_output)
    test_cases = [
        (0b01010101, 1),   # "-++-" -> Yes (binary: 01 10 10 01)
        (0b10010000, 0),   # "+-"   -> No  (binary: 10 01 00 00)
        (0b10100000, 1),   # "++"   -> Yes (binary: 10 10 00 00)
        (0b01000000, 0),   # "-"    -> No  (binary: 01 00 00 00)
        (0b10100101, 1)    # "++--++" -> Yes
    ]
    
    # Clock generator
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut._log.info("Starting tests")
    passed = 0
    total = len(test_cases)
    
    for input_data, expected in test_cases:
        # Apply reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Apply inputs
        dut.data.value = input_data
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for processing (8 cycles)
        await ClockCycles(dut.clk, 8)
        
        # Check output
        if dut.done.value == 1 and dut.result.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: Input {bin(input_data)} Expected {expected} Got {dut.result.value}")
    
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total