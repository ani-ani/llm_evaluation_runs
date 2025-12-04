import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

MOD = 1000000007

@cocotb.test()
async def test_penguin(dut):
    # Test cases (original scaled to n<=16, k<=8)
    test_cases = [
        (5, 2, 54),
        (7, 4, 1728),
        (8, 5, 16875),
        (8, 8, 2097152 % MOD),
        (1, 1, 1),
        (3, 3, 9)
    ]
    
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    passed = 0
    total = len(test_cases)
    
    for n_val, k_val, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Apply inputs
        dut.n.value = n_val
        dut.k.value = k_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 25 cycles)
        for _ in range(25):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check result
        if dut.result.value == expected:
            passed += 1
        else:
            dut._log.error("Test failed: n=%d, k=%d = %%d, expected %%d" \\
                          % (dut.result.value, expected))
    
    dut._log.info(f"{passed}/{total} tests passed")