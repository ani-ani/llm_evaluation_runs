import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_assembler(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    test_cases = [
        {
            "k": 2,
            "symbols": [0, 1],  # a=0, b=1
            "time_table": [[3,5],[6,2]],
            "result_table": [[1,1],[0,1]],
            "seq": [0,1,0],  # aba
            "seq_len": 3,
            "expected": (9,1)  # 9-b
        },
        {
            "k": 2,
            "symbols": [0,1],
            "time_table": [[3,5],[6,2]],
            "result_table": [[1,1],[0,1]],
            "seq": [1,1,0],  # bba
            "seq_len": 3,
            "expected": (8,0)  # 8-a
        }
    ]

    passed = 0
    dut.start.value = 0

    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for case in test_cases:
        # Load inputs
        dut.k.value = case["k"]
        for i in range(8):
            dut.symbols[i].value = case["symbols"][i] if i < len(case["symbols"]) else 0
            for j in range(8):
                if i < case["k"] and j < case["k"]:
                    dut.time_table[i][j].value = case["time_table"][i][j]
                    dut.result_table[i][j].value = case["result_table"][i][j]
                else:
                    dut.time_table[i][j].value = 0
                    dut.result_table[i][j].value = 0
        dut.seq_len.value = case["seq_len"]
        for i in range(8):
            dut.seq[i].value = case["seq"][i] if i < case["seq_len"] else 0

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)

        # Check results
        expected_time, expected_sym = case["expected"]
        if dut.min_time.value == expected_time and dut.result_sym.value == expected_sym:
            passed += 1
        else:
            dut._log.error(f"Test failed: Got {dut.min_time.value}-{dut.result_sym.value}, expected {expected_time}-{expected_sym}")
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")