import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_energy_balance(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (scaled to 4 lamps)
    test_cases = [
        {
            'n': 4,
            'x': [10,10,20,20],
            'y': [10,20,10,20],
            'e': [5,5,5,5],
            'expected': 28.0,
            'possible': True
        },
        {
            'n': 2,
            'x': [4,8],
            'y': [4,8],
            'e': [2,3],
            'expected': 0.0,
            'possible': False
        }
    ]

    passed = 0
    for test in test_cases:
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load inputs
        dut.n.value = test['n']
        for i in range(8):
            dut.x_i[i].value = test['x'][i] if i < test['n'] else 0
            dut.y_i[i].value = test['y'][i] if i < test['n'] else 0
            dut.e_i[i].value = test['e'][i] if i < test['n'] else 0

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check results
        if test['possible']:
            expected_fp = int(test['expected'] * (1 << 16))
            tolerance = int(0.0001 * (1 << 16))  # 0.0001 precision
            actual = dut.min_length.value
            if abs(actual - expected_fp) < tolerance:
                passed += 1
            else:
                actual_float = actual / (1 << 16)
                dut._log.error("Test failed: Expected {} ({} fixed), Got {} ({})".format(
                    test['expected'], expected_fp, actual_float, actual))
        else:
            if dut.impossible.value:
                passed += 1
            else:
                dut._log.error("Test should be impossible but got solution")

        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1

    dut._log.info("{} / {} tests passed".format(passed, len(test_cases)))