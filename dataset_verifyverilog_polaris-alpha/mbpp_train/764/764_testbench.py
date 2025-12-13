import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

@cocotb.test()
async def test_digit_counter(dut):
    # Test cases (original + padded to 16 chars with nulls)
    test_cases = [
        (bytes('program2bedone\0\0\0', 'ascii'), 1),  # Test 1
        (bytes('3wonders\0\0\0\0\0\0\0\0', 'ascii'), 1),  # Test 2
        (bytes('123\0\0\0\0\0\0\0\0\0\0\0\0\0', 'ascii'), 3),  # Test 3
        (bytes('3wond-1ers2\0\0\0\0\0', 'ascii'), 3)   # Test 4
    ]
    passed = 0
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    for data_in, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load test data
        dut.str.value = int.from_bytes(data_in, 'big')
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 16 cycles
        await ClockCycles(dut.clk, 16)
        
        # Verify result
        if dut.count.value == expected:
            passed += 1
            dut._log.info(f"PASS: {data_in} => {dut.count.value}")
        else:
            dut._log.error(f"FAIL: {data_in} => {dut.count.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")