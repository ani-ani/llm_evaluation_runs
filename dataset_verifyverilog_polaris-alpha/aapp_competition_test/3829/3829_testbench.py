import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_expectation(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        (6, 1, 3.5),
        (6, 3, 4.958333333333),
        (2, 2, 1.75),
        (1, 1, 1.0),
        (8, 4, None)  # Computed baseline
    ]
    passed = 0
    total = len(test_cases)
    
    # Precompute Q16.16 expectation for (8,4)
    m, n = 8, 4
    tsum = sum(pow(i/m, n) for i in range(1, m))
    expect_8_4 = int(round((m - tsum) * 65536))
    test_cases[3] = (8,4, expect_8_4 / 65536.0)
    
    for m_val, n_val, expected in test_cases:
        # Apply reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.m.value = m_val
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Get result
        res_fixed = dut.result.value.integer
        actual = res_fixed / 65536.0
        q16_expected = int(round(expected * 65536))
        
        # Verify
        if abs(res_fixed - q16_expected) <= 150:  # Allow ~0.002 error
            passed += 1
        else:
            dut._log.error(f"Case m={m_val},n={n_val} failed: Actual {actual:.6f} ({res_fixed}), Expected {expected:.6f} ({q16_expected}), Δ={actual-expected:.6f}")
    
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total