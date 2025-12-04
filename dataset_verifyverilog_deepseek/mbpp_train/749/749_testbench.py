import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_sorter(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    # Custom function to convert string list to integers
    def prepare_testcase(str_list, max_elements=8):
        int_list = [int(s.strip()) for s in str_list[:max_elements]]
        int_list.extend([0]*(max_elements - len(int_list)))
        return int_list

    # Adapted test cases (original truncated to 8 elements)
    test_cases = [
        (['4','12','45','7','0','100','200','-12'], [-12, 0, 4, 7, 12, 45, 100, 200]),
        (['2','3','8','4','7','9','8','2'], [2, 2, 3, 4, 7, 8, 8, 9]),
        (['1','3','5','7','1','3','13','15'], [1, 1, 3, 3, 5, 7, 13, 15]),
        (['-5','100','-20','73','0','-1','42','33'], [-20, -5, -1, 0, 33, 42, 73, 100])
    ]

    passed = 0
    for input_str_list, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Prepare input
        inputs = prepare_testcase(input_str_list)
        for i in range(8):
            dut.numbers[i].value = inputs[i]

        # Start sorting
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check results
        result = [int(dut.sorted[i].value.signed_integer) for i in range(8)]
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {input_str_list} -> {result}")
        else:
            dut._log.error(f"FAIL: {input_str_list} -> {result}, expected {expected}")

        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)