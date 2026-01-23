import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

async def setup_dut(dut):
    # Create a clock generator on port 'clk'
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.s.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    return

@cocotb.test()
async def test_snake_exhibition(dut):
    """Test the snake_exhibition module with various configurations."""
    await setup_dut(dut)

    # Define test cases (n, s_int, expected_result)
    # s encoding: 0='-', 1='<', 2='>'
    # Since s is 8 bits, we pack it as a byte. bit[1:0] is index 0, bit[3:2] is index 1, etc.
    # 00 = -, 01 = <, 10 = >
    def pack_s(s_str):
        res = 0
        for i, char in enumerate(s_str):
            val = 0
            if char == '<': val = 1
            elif char == '>': val = 2
            res |= (val << (2*i))
        return res

    test_cases = [
        (4, "-><-", 3), # Example 1
        (5, ">>>>>", 5), # Example 2
        (3, "<--", 3),   # Example 3
        (2, "<>", 0),    # Example 4
        (2, "--", 2),    # All off
        (2, "<<", 2),    # All same
        (2, ">>", 2),    # All same
        (4, "<<>>", 0),  # Mixed
    ]

    passed = 0
    total = len(test_cases)

    for n, s_str, expected in test_cases:
        dut.n.value = n
        dut.s.value = pack_s(s_str)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 20 # Safety timeout
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
            
        if dut.done.value:
            actual = int(dut.result.value)
            if actual == expected:
                passed += 1
                dut._log.info(f"PASS: n={n}, s='{s_str}' -> {actual} (Expected {expected})")
            else:
                dut._log.error(f"FAIL: n={n}, s='{s_str}' -> {actual} (Expected {expected})")
        else:
            dut._log.error(f"TIMEOUT: n={n}, s='{s_str}'")

        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    dut._log.info(f"Summary: {passed}/{total} tests passed.")
    assert passed == total, f"Only {passed}/{total} tests passed"
