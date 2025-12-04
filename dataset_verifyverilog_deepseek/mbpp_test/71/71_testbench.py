import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_comb_sort(dut):
    # Clock generator
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    async def reset():
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        dut.start.value = 0
        dut.data_in.value = 0

    def pack_data(data):
        return sum((val << (8*i)) for i, val in enumerate(data))

    def unpack_data(packed):
        return [(packed >> (8*i)) & 0xFF for i in range(8)]

    # Test cases (padded to 8 elements with zeros)
    test_cases = [
        ([5,15,37,25,79,0,0,0], [0,5,15,25,37,79,0,0]),
        ([41,32,15,19,22,0,0,0], [0,15,19,22,32,41,0,0]),
        ([99,15,13,47,0,0,0,0], [0,0,13,15,47,99,0,0]),
        ([8,7,6,5,4,3,2,1], [1,2,3,4,5,6,7,8]),
        ([255,128,1,0,64,32,16,8], [0,1,8,16,32,64,128,255])
    ]

    await reset()
    passed = 0

    for input_data, expected in test_cases:
        dut.data_in.value = pack_data(input_data)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (max 200 cycles)
        for _ in range(200):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break

        result = unpack_data(dut.data_out.value)
        # Compare only relevant portions (ignore zero padding)
        non_zero_input = [x for x in input_data if x != 0]
        valid_result = result[:len(non_zero_input)]
        expected_trimmed = sorted(non_zero_input)

        if valid_result == expected_trimmed:
            dut._log.info(f"PASS: {input_data} -> {valid_result}")
            passed += 1
        else:
            dut._log.error(f"FAIL: {input_data} -> {valid_result}, expected {expected_trimmed}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)