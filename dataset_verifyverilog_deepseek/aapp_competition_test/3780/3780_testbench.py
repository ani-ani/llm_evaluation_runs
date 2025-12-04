import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import math

# Q16.16 conversion helpers
def float_to_q16_16(f):
    return int(f * (1 << 16)) & 0xFFFFFFFF

def q16_16_to_float(q):
    return q / (1 << 16) if q < 0x80000000 else (q - 0x100000000) / (1 << 16)

@cocotb.test()
async def test_rescue_calculator(dut):
    clock = Clock(dut.clk, 10, units="ns")  # Create a 10ns period clock
    cocotb.start_soon(clock.start())  # Start the clock

    # Test cases (original scaled to 16-bit)
    test_cases = [
        # Input: (x1,y1,x2,y2, vmax, wind_time, vx,vy, wx,wy, expected_time)
        (0, 0, 5, 5, 3, 2, -1, -1, -1, 0, 3.729935587093555327),
        (0, 0, 0, 100, 100, 1000, -50, 0, 50, 0, 11.547005383792516398),
        (-10, -10, 10, 10, 2, 1, -1, 0, 0, -1, 2.1892547876100074689)
    ]

    passed = 0
    for case in test_cases:
        # Reset device
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Apply test case inputs
        x1, y1, x2, y2, vmax, wt, vx, vy, wx, wy, exp_time = case
        dut.x1.value = x1
        dut.y1.value = y1
        dut.x2.value = x2
        dut.y2.value = y2
        dut.v_max.value = vmax
        dut.t_wind.value = wt
        dut.vx.value = vx
        dut.vy.value = vy
        dut.wx.value = wx
        dut.wy.value = wy

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done signal (16 cycles + 2 for reset)
        for _ in range(20):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break

        # Check result (1% tolerance for fixed-point quantization)
        result = q16_16_to_float(int(dut.min_time.value))
        tolerance = 0.01 * abs(exp_time)
        if abs(result - exp_time) < tolerance or abs(result - exp_time) < 1e-6:
            passed += 1
        else:
            dut._log.error(
                f"Test failed: Got {result:.6f}, expected {exp_time:.6f}"
            )
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
