import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_roman_digits_solver(dut):
    """Test the roman digits solver module"""
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases from the prompt
    test_cases = [
        (1, 4),
        (2, 10),
        (10, 244),
        (3, 20),
        (4, 35),
        (5, 56),
        (6, 83),
        (7, 116),
        (8, 155),
        (9, 198),
        (11, 292),
        (12, 341),
        (13, 390),
        (14, 439),
        (20, 733),
        (21, 782),  # 49*21 - 247 = 1029 - 247 = 782
        (100, 4653), # 49*100 - 247 = 4900 - 247 = 4653
        (1000, 48753), # 49*1000 - 247 = 49000 - 247 = 48753
        (1000000000, 48999999753) # 49*10^9 - 247 = 49000000000 - 247 = 48999999753
    ]

    passed = 0
    total = len(test_cases)

    for n_in, expected in test_cases:
        # Start sequence
        dut.n.value = n_in
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 50:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 50:
            raise TestFailure(f"Test timed out for n={n_in}")

        # Check result
        actual = int(dut.result.value)
        if actual == expected:
            passed += 1
        else:
            print(f"FAILED: n={n_in}, Expected={expected}, Got={actual}")
            raise TestFailure(f"Mismatch for n={n_in}: expected {expected}, got {actual}")

        await RisingEdge(dut.clk) # Idle cycle

    print(f"
Test Summary: {passed}/{total} tests passed")
