import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_incremental_string(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        (2, 650, (26,25,26), False),  # "zyz"
        (2, 651, (0,0,0), True),      # error
        (1, 1, (1,0,0), False),       # "a" (single char)
        (1, 26, (26,0,0), False),     # "z"
        (1, 27, (0,0,0), True)        # error
    ]
    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    for k_val, n_val, expected_str, expect_err in test_cases:
        dut.k.value = k_val
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.clk)  # Wait 1 cycle for result
        if dut.done.value == 1:
            result = (dut.string_out.value[14:10].integer, dut.string_out.value[9:5].integer, dut.string_out.value[4:0].integer)
            if dut.err.value == (1 if expect_err else 0):
                if not expect_err and result == expected_str:
                    passed += 1
                elif expect_err:
                    passed += 1
                else:
                    dut._log.error(f"Test failed: k={k_val} n={n_val} → Result:{result} Expected:{expected_str}, err={dut.err.value}")
            else:
                dut._log.error(f"Err flag mismatch: k={k_val} n={n_val} → err={dut.err.value} expected={expect_err}")
        else:
            dut._log.error(f"Done not asserted for k={k_val}/n={n_val}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)