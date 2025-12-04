import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

def float_to_q16_16(f):
    return int(f * (1 << 16))

@cocotb.test()
async def test_complex_polar(dut):
    clock = Clock(dut.clk, 10, units="ns")  # Create 100MHz clock
    cocotb.start_soon(clock.start())  # Start the clock

    # Reset system
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    test_cases = [
        # Inputs (real, imag) | Expected (magnitude, phase)
        (float_to_q16_16(1), float_to_q16_16(0), float_to_q16_16(1.0), float_to_q16_16(0.0)),
        (float_to_q16_16(4), float_to_q16_16(0), float_to_q16_16(4.0), float_to_q16_16(0.0)),
        (float_to_q16_16(5), float_to_q16_16(0), float_to_q16_16(5.0), float_to_q16_16(0.0)),
        (float_to_q16_16(1), float_to_q16_16(1), float_to_q16_16(1.4142), float_to_q16_16(math.pi/4))
    ]

    passed = 0
    TOLERANCE = 50  # Allow ±50 in fixed-point units (~0.00076 error)

    for real, imag, exp_mag, exp_phase in test_cases:
        # Apply inputs
        dut.real_part.value = real
        dut.imag_part.value = imag
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check results with tolerance
        mag_ok = abs(int(dut.magnitude.value) - exp_mag) <= TOLERANCE
        phase_ok = abs(int(dut.phase.value) - exp_phase) <= TOLERANCE

        if mag_ok and phase_ok:
            dut._log.info(f"PASS: Input ({real>>16} + j{imag>>16}) => Mag={dut.magnitude.value.integer/(1<<16):.4f}, Phase={dut.phase.value.integer/(1<<16):.4f}")
            passed += 1
        else:
            dut._log.error(f"FAIL: Input ({real>>16} + j{imag>>16})
  Got: Mag={dut.magnitude.value.integer/(1<<16):.4f}, Phase={dut.phase.value.integer/(1<<16):.4f}
  Exp: Mag={exp_mag/(1<<16):.4f}, Phase={exp_phase/(1<<16):.4f}")

        await RisingEdge(dut.clk)  # Wait one cycle between tests

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")