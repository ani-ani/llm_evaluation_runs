import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_next_bigger(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_cases = [
        (12, 21, False),
        (10, 0, True),
        (102, 120, False),
        (320, 320, True),  # No bigger case
        (321, 321, True)  # Descending digits
    ]
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await Timer(5, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    
    for inp_val, exp_val, exp_no_bigger in test_cases:
        # Start computation
        dut.num.value = inp_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 5 cycles for result
        for _ in range(5):
            await RisingEdge(dut.clk)
            
        # Check outputs
        if (exp_no_bigger):
            if dut.no_bigger.value == 1:
                passed += 1
                dut._log.info(f"PASS: {inp_val} no bigger number")
            else:
                dut._log.error(f"FAIL: {inp_val} expected no_bigger
Got next_num={dut.next_num.value}, no_bigger={dut.no_bigger.value}")
        else:
            if dut.next_num.value == exp_val and dut.no_bigger.value == 0:
                passed += 1
                dut._log.info(f"PASS: {inp_val} -> {exp_val}")
            else:
                dut._log.error(f"FAIL: {inp_val} -> {dut.next_num.value}, expected {exp_val}")
        
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")