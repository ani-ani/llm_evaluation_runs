import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

def calculate_expected(L):
    temp = L * 226
    quotient, remainder = divmod(temp, 355)
    r_squared = quotient + (1 if remainder else 0)
    return math.ceil(math.sqrt(r_squared)) if r_squared else 0

@cocotb.test()
async def test_dog_chain(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        (4, 2),
        (314, 15),
        (1, 1),
        (255, 13)
    ]
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    passed = 0
    for L_val, expected in test_cases:
        dut.start.value = 1
        dut.L.value = L_val
        await RisingEdge(dut.clk)
        dut.start.value = 0
        cycles = 0
        while not dut.done.value:
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > 50:
                assert False, "Timeout waiting for done"
        result = dut.chain_length.value.integer
        calc_exp = calculate_expected(L_val)
        if result == calc_exp:
            passed += 1
        else:
            dut._log.error(f"Error: L={L_val} Got:{result} Expected:{calc_exp}")
        await RisingEdge(dut.clk)
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
