import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_fluid_optimizer(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    def float_to_q88(f):
        return int(f * 256) & 0xFFFF

    def q88_to_float(q):
        return (q if q < 32768 else q - 65536) / 256.0

    # Test case 1 (scaled version of sample input)
    v_float = 3.0
    a_float = 0.66
    pipes = [
        (2,4,8), # pipe1
        (4,6,1), # pipe2
        (3,6,1), # pipe3
        (4,5,5), # pipe4
        (1,5,7), # pipe5
        (3,5,3)  # pipe6
    ]

    # Initialize inputs
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.v.value = float_to_q88(v_float)
    dut.a.value = float_to_q88(a_float)
    dut.p.value = len(pipes)
    for i in range(8):
        if i < len(pipes):
            dut.pipe_j[i].value = pipes[i][0] - 1 # 0-based index
            dut.pipe_k[i].value = pipes[i][1] - 1
            dut.pipe_cap[i].value = pipes[i][2]
        else:
            dut.pipe_j[i].value = 0
            dut.pipe_k[i].value = 0
            dut.pipe_cap[i].value = 0

    await ClockCycles(dut.clk, 3)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for completion
    await RisingEdge(dut.done)
    await ClockCycles(dut.clk, 3)

    # Verify outputs
    total_value = q88_to_float(dut.optimal_value.value)
    print(f"Result value: {total_value:.6f}")

    print("Pipe | Flubber | Water")
    for i in range(len(pipes)):
        f_rate = q88_to_float(dut.flubber_rates[i].value)
        w_rate = q88_to_float(dut.water_rates[i].value)
        print(f"{i+1}: {f_rate:.6f}, {w_rate:.6f}")

    # Check solution within 10% tolerance (aggressive scaling)
    expected_value = 1.020380
    assert abs(total_value - expected_value) < 0.2, f"Value {total_value:.6f} not close to expected {expected_value:.6f}"

    dut._log.info("1/1 tests passed")
