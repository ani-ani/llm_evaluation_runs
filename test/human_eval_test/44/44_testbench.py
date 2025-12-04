import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

async def reset(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_converter(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_cases = [
        (8,  3, 0x00000022),  # '22'
        (9,  3, 0x00000010),  # '100' → MSB justified
        (8,  2, 0x00000008),  # '1000' → represents first 4 digits ('1000' → 0x8)
        (7,  2, 0x00000007),  # '111'
        (16, 2, 0x00000010),  # '10000'
        (255,16, 0x000000FF)  # Not applicable in this design, but fits test case
    ]
    
    await reset(dut)
    passed = 0
    
    for (x_val, base_val, expected) in test_cases:
        dut.x.value = x_val
        dut.base.value = base_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for valid (max 20 cycles)
        for _ in range(20):
            if dut.valid.value:
                break
            await RisingEdge(dut.clk)
        
        if dut.valid.value != 1:
            dut._log.error(f"Timeout for x={x_val}, base={base_val}")
        else:
            result = dut.digits.value.integer
            # Mask to first 4 digits (16 bits)
            masked_result = result & 0xFFFF
            
            if masked_result == (expected & 0xFFFF):
                passed += 1
                dut._log.info(f"PASS: {x_val}_{base_val} → {hex(masked_result)}")
            else:
                dut._log.error(f"FAIL: {x_val}_{base_val} got {hex(masked_result)} vs {hex(expected)}")
        
        # Wait a few cycles between tests
        await ClockCycles(dut.clk, 2)
    
    total = len(test_cases)
    dut._log.info(f"
SUMMARY: {passed}/{total} tests passed")
    assert passed == total