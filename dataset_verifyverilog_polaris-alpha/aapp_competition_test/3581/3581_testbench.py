import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_arcade(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Q10.10 helper functions
    def fp10(x):
        return int(x * (1 << 10))
    
    # Scaled test data (original sample input N=4)
    test_data = {
        "num_rows": 4,
        "payouts": [40, 30, 30, 40, 20, 40, 50, 30, 30, 50],
        "probs": [
            [fp10(0.0), fp10(0.0), fp10(0.45), fp10(0.45), fp10(0.1)],
            [fp10(0.0), fp10(0.3), fp10(0.3), fp10(0.3), fp10(0.1)],
            [fp10(0.3), fp10(0.0), fp10(0.3), fp10(0.3), fp10(0.1)],
            [fp10(0.0), fp10(0.3), fp10(0.3), fp10(0.3), fp10(0.1)],
            [fp10(0.2), fp10(0.2), fp10(0.2), fp10(0.2), fp10(0.2)],
            [fp10(0.3), fp10(0.0), fp10(0.3), fp10(0.3), fp10(0.1)],
            [fp10(0.0), fp10(0.8), fp10(0.0), fp10(0.0), fp10(0.2)],
            [fp10(0.4), fp10(0.4), fp10(0.0), fp10(0.0), fp10(0.2)],
            [fp10(0.4), fp10(0.4), fp10(0.0), fp10(0.0), fp10(0.2)],
            [fp10(0.8), fp10(0.0), fp10(0.0), fp10(0.0), fp10(0.2)]
        ]
    }
    
    # Apply reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    # Load inputs
    dut.start.value = 0
    dut.num_rows.value = test_data["num_rows"]
    for i in range(10):
        dut.payouts[i].value = test_data["payouts"][i]
        for j in range(5):
            dut.probs[i][j].value = test_data["probs"][i][j]
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    # Verify result (convert Q10.22 to float)
    expected = 32.6405
    actual = dut.expected_value.value.signed_integer / (1 << 22)
    tolerance = 0.01  # Account for fixed-point precision
    
    assert abs(actual - expected) < tolerance, "Test failed: Expected %f, got %f" % (expected, actual)
    dut._log.info("1/1 tests passed")