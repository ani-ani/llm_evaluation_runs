import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

@cocotb.test()
async def test_subsequence_counter(dut):
    """Test the subsequence counter module with various cases."""
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a00.value = 0
    dut.a01.value = 0
    dut.a10.value = 0
    dut.a11.value = 0
    dut.result_index.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Cases: (a00, a01, a10, a11, expected_valid, expected_string)
    test_cases = [
        (1, 2, 2, 1, 1, "0110"),   # Example 2
        (1, 2, 3, 4, 0, ""),       # Example 1 (Impossible)
        (0, 0, 0, 0, 1, ""),       # Empty string (we treat as valid, length 0)
        (0, 0, 0, 45, 1, "1111111111"), # Only 1s
        (1, 0, 0, 0, 1, "00"),     # Two 0s
        (3, 0, 0, 0, 1, "0000"),   # Four 0s
        (0, 0, 0, 1, 1, "11"),     # Two 1s
        (0, 1, 1, 1, 1, "101"),    # 101 check
        (0, 1, 1, 0, 1, "01"),     # Two chars
    ]

    passed = 0
    total = len(test_cases)

    for a00, a01, a10, a11, exp_valid, exp_str in test_cases:
        # Inputs
        dut.a00.value = a00
        dut.a01.value = a01
        dut.a10.value = a10
        dut.a11.value = a11
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        timeout = 0
        while dut.done.value == 0 and timeout < 500:
            await RisingEdge(dut.clk)
            timeout += 1
        
        # Check validity
        if int(dut.valid.value) == exp_valid:
            if exp_valid == 1:
                # Check length
                exp_len = len(exp_str)
                if int(dut.length.value) == exp_len:
                    # Check content
                    match = True
                    for i in range(exp_len):
                        dut.result_index.value = i
                        await Timer(1, units='ns') # Allow signal propagation
                        if int(dut.result_bit.value) != int(exp_str[i]):
                            match = False
                            break
                    if match:
                        passed += 1
                        dut._log.info(f"Case passed: {a00},{a01},{a10},{a11} -> {exp_str}")
                    else:
                        dut._log.error(f"Content mismatch: got bits, expected {exp_str}")
                else:
                    dut._log.error(f"Length mismatch: got {int(dut.length.value)}, expected {exp_len}")
            else:
                passed += 1
                dut._log.info(f"Case passed: {a00},{a01},{a10},{a11} -> Impossible")
        else:
            dut._log.error(f"Valid mismatch: got {int(dut.valid.value)}, expected {exp_valid}")

    dut._log.info(f"Summary: {passed}/{total} tests passed")
    assert passed == total, "Some tests failed"
