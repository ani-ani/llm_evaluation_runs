import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
from fixedpoint import FixedPoint

@cocotb.test()
async def test_mapper(dut):
    clock = Clock(dut.clk, 10, units="ns")  # 100MHz clock
    cocotb.start_soon(clock.start())
    test_cases = [
        # Test case 1: (1,1), (5,1), (5,5), (4,2) -> max(4,4)=4.00
        {'x0': FixedPoint(1, 8, 8).raw_bits,
         'y0': FixedPoint(1, 8, 8).raw_bits,
         'x1': FixedPoint(5, 8, 8).raw_bits,
         'y1': FixedPoint(1, 8, 8).raw_bits,
         'x2': FixedPoint(5, 8, 8).raw_bits,
         'y2': FixedPoint(5, 8, 8).raw_bits,
         'x3': FixedPoint(4, 8, 8).raw_bits,
         'y3': FixedPoint(2, 8, 8).raw_bits,
         'expected': FixedPoint(4.0, 16, 16).raw_bits}
    ]
    passed = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    
    for case in test_cases:
        # Load coordinates
        dut.x0.value = case['x0']
        dut.y0.value = case['y0']
        dut.x1.value = case['x1']
        dut.y1.value = case['y1']
        dut.x2.value = case['x2']
        dut.y2.value = case['y2']
        dut.x3.value = case['x3']
        dut.y3.value = case['y3']
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        await ClockCycles(dut.clk, 10)
        
        # Verify output
        expected_val = FixedPoint.from_raw(case['expected'], 16, 16, signed=False)
        actual_val = FixedPoint.from_raw(dut.side_length.value, 16, 16, signed=False)
        
        if abs(actual_val - expected_val) < 0.01:  # Allow 0.01 tolerance
            passed += 1
        else:
            dut._log.error("Test failed: Side length=%f, expected=%f" % 
                          (actual_val, expected_val))
    
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))