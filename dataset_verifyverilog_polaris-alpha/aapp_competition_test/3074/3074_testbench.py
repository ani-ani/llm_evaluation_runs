import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

MOD_VAL = 1000000007

@cocotb.test()
async def test_crypto_subsets(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases: (N, digits, expected)
    test_cases = [
        (3, [3,6,1], 3),
        (2, [1,1], 0),
        (4, [3,0,5,1], 6)
    ]

    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    passed = 0
    for (n, digits, expected) in test_cases:
        # Load digits
        dut.N.value = n
        dut.digit0.value = digits[0]
        dut.digit1.value = digits[1] if len(digits) > 1 else 0
        dut.digit2.value = digits[2] if len(digits) > 2 else 0
        dut.digit3.value = digits[3] if len(digits) > 3 else 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (20 cycles)
        for _ in range(30):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check result
        if int(dut.result.value) % MOD_VAL == expected:
            passed += 1
        else:
            dut._log.error("Test failed: N=%d, digits=%s, got %d (mod %d), expected %d
" % 
                          (n, str(digits), int(dut.result.value), MOD_VAL, expected))
    
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))