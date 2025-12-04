import cocotb
from cocotb.triggers import RisingEdge, Timer
import math

@cocotb.test()
async def test_solver(dut):
    cocotb.start_soon(cocotb.clock.Clock(dut.clk, 10, units="ns").start())
    test_cases = [
        # (a, b, M, P, expected_x)
        (1, 8, 10, 9, 1),   # x+8 ≡9 mod10 →x=1
        (1, 23, 5, 0, 2),   # x+23 ≡0 mod5 →x=2
        (18, 60, 7, 1, 1),  # 18x+60 ≡1 mod7 →x=1
        (3, 5, 11, 10, 10)  # 3x+5 ≡10 mod11 →x=10
    ]
    
    dut._log.info("Start test")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    passed = 0
    for a, b, M, P, expected in test_cases:
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        # Apply inputs
        dut.a.value = a
        dut.b.value = b
        dut.M.value = M
        dut.P.value = P
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait up to 20 cycles
        for _ in range(25):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        if dut.x.value != expected:
            dut._log.error(f"Failed: a={a}, b={b}, M={M}, P={P} → x={dut.x.value}, expected {expected}")
        else:
            passed += 1
        
        await Timer(10, units="ns")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)