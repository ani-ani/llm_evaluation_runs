import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import itertools

@cocotb.test()
async def test_wiring(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (m, photo1_sw, photo1_lgt, photo2_sw, photo2_lgt, expected)
    test_cases = [
        # m=0 → all possible wirings (4! = 24)
        (0, 0b0000, 0b0000, 0b0000, 0b0000, 24),
        
        # m=1, photo requires switch0→light0 (remaining 3! = 6 wirings)
        (1, 0b1000, 0b1000, 0b0000, 0b0000, 6),
        
        # m=2, impossible case (lights on with switches off)
        (2, 0b0000, 0b0010, 0b1000, 0b1000, 0)
    ]
    passed = 0
    
    for tc in test_cases:
        m, p1_sw, p1_lgt, p2_sw, p2_lgt, exp = tc
        dut.m.value = m
        dut.photo1_sw.value = p1_sw
        dut.photo1_lgt.value = p1_lgt
        dut.photo2_sw.value = p2_sw
        dut.photo2_lgt.value = p2_lgt
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.result.value == exp:
            passed += 1
        else:
            dut._log.error(f"Test failed: m={m} photos. Expected {exp}, got {dut.result.value}")
        await RisingEdge(dut.clk)  # wait done deassert
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)