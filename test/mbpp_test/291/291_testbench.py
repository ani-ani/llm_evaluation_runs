import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_fence(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    test_cases = [
        (2, 4, 16),
        (3, 2, 6),
        (4, 4, 228),
        (8, 4, 0)  # Actual value calculated in TB
    ]

    passed = 0
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    for n, k, expected in test_cases:
        # Special case for n=8 calculation
        if n == 8 and k == 4:
            # Manually compute expected: expected = (4-1)*(prev + prev_prev)
            # n=4:228, n=5:3*(228+84)=936, n=6:3*(936+228)=3492, n=7:3*(3492+936)=13284, n=8:3*(13284+3492)=50328
            expected = 50328

        # Load inputs
        dut.n.value = n
        dut.k.value = k
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
            
        # Check result
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: n={n}, k={k} => {expected}")
        else:
            dut._log.error(f"FAIL: n={n}, k={k} => {int(dut.result.value)} (expected {expected})")
        
        # Reset state
        await RisingEdge(dut.clk)
    
    # Summary
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")