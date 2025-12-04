import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_rounder(dut):
    clock = Clock(dut.clk, 10, units="ns")  # Create clock
    cocotb.start_soon(clock.start())  # Start clock

    # Test cases (original adapted for 15 char max)
    test_cases = [
        # input            t  expected output
        ("10.245",         1, "10.25"),
        ("10.245",         2, "10.3"),
        ("9.2",            100, "9.2"),
        ("999.999",        2, "1000"),
        ("9.9999",         1, "10"),
        ("99.99",          1, "100"),
        ("5.59",           1, "6")  # Verify carry before decimal
    ]

    passed = 0
    for grade_str, t_val, expected in test_cases:
        # Reset module
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Prepare inputs
        dut.grade_len.value = len(grade_str)
        padded_grade = grade_str.ljust(15, ' ')
        grade_bytes = [ord(c) for c in padded_grade]
        dut.grade_in.value = int(''.join(f'{b:08b}' for b in grade_bytes), 2)
        dut.t_in.value = min(t_val, 4)

        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Read output
        out_bytes = [(dut.grade_out.value >> i*8) & 0xff for i in reversed(range(15))]
        result = ''.join(chr(b) for b in out_bytes).strip()
        valid_len = dut.out_len.value
        filtered_result = ''.join(result[i] for i in range(valid_len))

        # Check result
        if filtered_result == expected:
            passed += 1
        else:
            dut._log.error(f"FAIL: {grade_str} t={t_val} -> '{filtered_result}' (expected '{expected}')")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
