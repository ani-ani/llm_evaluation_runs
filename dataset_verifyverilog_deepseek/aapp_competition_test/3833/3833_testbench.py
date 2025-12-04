import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_max_substring(dut):
    """Test max substring rearrangement"""
    # Test cases (input_s, input_t, expected_output, s_len, t_len)
    test_cases = [
        (
            int('1011010000000000', 2), 6,
            int('1100000000000000', 2), 3,
            int('1101100000000000', 2)
        ),
        (
            int('1001011000000000', 2), 8,
            int('1000110000000000', 2), 6,
            int('1000110100000000', 2)
        ),
        (
            int('1000000000000000', 2), 1,
            int('1111100000000000', 2), 5,
            int('0000000000000000', 2)  # Impossible case - fallback to sorted
        ),
        (
            int('1101100000000000', 2), 8,
            int('1010000000000000', 2), 3,
            int('1011010000000000', 2)
        )
    ]
    
    # Create clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Initialize and reset
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    for s_val, s_len, t_val, t_len, expected in test_cases:
        # Apply inputs
        dut.s_in.value = s_val
        dut.s_len.value = s_len
        dut.t_in.value = t_val
        dut.t_len.value = t_len
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 32 cycles)
        for _ in range(40):
            await RisingEdge(dut.clk)
            if dut.ready.value == 1:
                break
        else:
            assert False, "Timeout waiting for ready"
        
        # Check result
        result = dut.result.value
        mask = (0xFFFF >> (16 - s_len)) << (16 - s_len)
        if (result & mask) == (expected & mask):
            passed += 1
        else:
            actual_str = bin(result)[2:].zfill(16)[:s_len]
            exp_str = bin(expected)[2:].zfill(16)[:s_len]
            dut._log.error(f"Test failed:
  Input s={bin(s_val)[2:].zfill(16)[:s_len]}
  Input t={bin(t_val)[2:].zfill(16)[:t_len]}
  Output={actual_str}
  Expected={exp_str}")
        
        # Wait a cycle before next test
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed informationally")
    # Always pass simulation (assertions are per-test)
    if passed < len(test_cases):
        raise cocotb.result.TestFailure("One or more tests failed")
