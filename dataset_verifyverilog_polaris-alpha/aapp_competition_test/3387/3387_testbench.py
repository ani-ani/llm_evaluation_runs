import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

# Fixed-point conversion helpers
def float_to_q16(val):
    return int(round(val * 65536))

def q16_to_float(val):
    return val / 65536.0

@cocotb.test()
async def test_allocator(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await Timer(15, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test case 1: 3 species with equal demand
    tc1_input = {
        "t_fixed": float_to_q16(10),
        "a": [(0,10,1)]*4,
        "b": [(0,10,1)]*4,
        "d": [float_to_q16(1)]*3 + [0]
    }
    # Expected outputs (3 equal allocations, last is 0)
    expected1 = [10/3]*3 + [0]

    # Test case 2: Species with constraints
    tc2_input = {
        "t_fixed": float_to_q16(10),
        "a": [(0,1,1000), (2,8,2), (2,8,1), (0,0,0)],
        "b": [(1,1,1000), (8,8,2), (8,8,1), (0,0,0)],
        "d": [float_to_q16(d) for d in [1000,2,1,0]]
    }
    # Convert Q16 outputs to floats for verification
    expected2 = [1.0, 6.0, 3.0, 0.0]

    test_cases = [
        (tc1_input, expected1),
        (tc2_input, expected2)
    ]

    passed = 0
    for tc_idx, (inputs, expected) in enumerate(test_cases):
        # Load inputs
        dut.t_fixed.value = inputs["t_fixed"]
        dut.a0.value = float_to_q16(inputs["a"][0][0])
        dut.b0.value = float_to_q16(inputs["a"][0][1])
        dut.d0.value = inputs["d"][0]
        dut.a1.value = float_to_q16(inputs["a"][1][0])
        dut.b1.value = float_to_q16(inputs["a"][1][1])
        dut.d1.value = inputs["d"][1]
        dut.a2.value = float_to_q16(inputs["a"][2][0])
        dut.b2.value = float_to_q16(inputs["a"][2][1])
        dut.d2.value = inputs["d"][2]
        dut.a3.value = float_to_q16(inputs["a"][3][0])
        dut.b3.value = float_to_q16(inputs["a"][3][1])
        dut.d3.value = inputs["d"][3]

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (50 cycles max)
        for _ in range(60):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            assert False, "Timeout waiting for done"

        # Verify outputs
        tol = 0.0001  # 0.01% tolerance for fixed-point
        outputs = [
            q16_to_float(dut.x0.value),
            q16_to_float(dut.x1.value),
            q16_to_float(dut.x2.value),
            q16_to_float(dut.x3.value)
        ]

        passed_case = True
        for i, (actual, exp) in enumerate(zip(outputs, expected)):
            if abs(actual - exp) > tol:
                dut._log.error(f"TC{tc_idx+1}: Species {i} got {actual:.6f}, expected {exp:.6f}")
                passed_case = False

        if passed_case:
            passed += 1
            dut._log.info(f"Test case {tc_idx+1} passed")
        else:
            dut._log.error(f"Test case {tc_idx+1} failed")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)