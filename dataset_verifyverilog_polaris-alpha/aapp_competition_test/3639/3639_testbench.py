import cocotb\\
from cocotb.clock import Clock\\
from cocotb.triggers import RisingEdge, FallingEdge, Timer\\
import numpy as np\\
\\
def float_to_q16_16(f):\\
    return int(f * (1 << 16))\\
\\
def q16_16_to_float(q):\\
    return q / (1 << 16) if q >=0 else -(-q) / (1 << 16)\\\
\\
@cocotb.test()\\
async def test_optimal_cycling(dut):\\
    clock = Clock(dut.clk, 10, units="ns")\\
    cocotb.start_soon(clock.start())\
\\
    # Test case 1: No rain, verify sweat-only calculation\\
    rain_data1 = [0]*16\\
    c_val1 = 0.1\\
    d_val1 = 2.0\\
    expected1 = 288 # Sweat only: 0.1 * (12 km/h)^2 * (10 mins) = 144, but travel time = 2/12*60=10mins\\
\\
    # Test case 2: Heavy rain in middle section (adapted to fit T=16)\\
    rain_data2 = [0,0,0,100,100,100] + [1]*10\\
    rain_data2 = rain_data2[:16]\\
    expected2 = 24 # Hand-calculated optimal path between showers\\
\\
    test_cases = [\\
        (5, c_val1, d_val1, rain_data1, expected1),\\
        (6, 0.01, 2.0, rain_data2, expected2) # Note T=6 matches rain_data2 length\\
    ]\\
\\
    passed = 0\\
    for T_val, c_float, d_float, rain_arr, expected in test_cases:\\
        # Reset device\\
        dut.rst_n.value = 0\\
        dut.start.value = 0\\
        await RisingEdge(dut.clk)\\
        await RisingEdge(dut.clk)\\
        dut.rst_n.value = 1\\
        await RisingEdge(dut.clk)\\
\\
        # Convert inputs to fixed point\\
        dut.T.value = T_val\\
        dut.c_fp.value = float_to_q16_16(c_float)\\
        dut.d_fp.value = float_to_q16_16(d_float)\\
        for i in range(16):\\
            dut.rain[i].value = rain_arr[i] if i < T_val else 0\\
\\
        # Start computation\\
        dut.start.value = 1\\
        await RisingEdge(dut.clk)\\
        dut.start.value = 0\\
\\
        # Wait until done\\
        while not dut.done.value:\\
            await RisingEdge(dut.clk)\\
\\
        # Check results (allow 1% error)\\
        result_float = q16_16_to_float(dut.min_wetness_fp.value.integer)\
        if abs(result_float - expected) / expected < 0.01:\\
            passed += 1\\
        else:\\
            dut._log.error(f"Test failed: Expected {expected}, got {result_float}")\
\\
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")