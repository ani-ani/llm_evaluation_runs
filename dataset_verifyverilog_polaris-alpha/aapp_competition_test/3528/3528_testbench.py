import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import ast

@cocotb.test()
async def test_convex_hull(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Scale Sample Input 1 (5 nails) to 16-bit
    test1 = {
        "num_nails": 5,
        "nail_x": [1, 2, 4, 3, 5],
        "nail_y": [4, 2, 1, 5, 3],
        "remove_seq": [0, 2, 1],  # L=0, U=2, R=1
        "expected": [90, 65, 25]  # 9.0x10,6.5x10,2.5x10
    }

    # Scale Sample Input 2 (8 nails, use first 8)
    test2 = {
        "num_nails": 8,
        "nail_x": [1,2,3,4,5,6,7,8],
        "nail_y": [6,4,1,2,7,5,9,3],
        "remove_seq": [2,1,3,0,2,2],  # U,R,D,L,U,U
        "expected": [340,240,165,140,95,50]  # 34x10,24x10,...
    }

    tests = [test1, test2]
    passed = 0

    for test in tests:
        dut.rst_n.value = 0
        dut.start.value = 0
        await ClockCycles(dut.clk, 3)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load inputs
        dut.num_nails.value = test["num_nails"]
        for i in range(8):
            if i < test["num_nails"]:
                dut.nail_x[i].value = test["nail_x"][i]
                dut.nail_y[i].value = test["nail_y"][i]
            else:
                dut.nail_x[i].value = 0
                dut.nail_y[i].value = 0
        for i in range(6):
            if i < test["num_nails"]-2:
                dut.remove_seq[i].value = test["remove_seq"][i]
            else:
                dut.remove_seq[i].value = 0

        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.clk)

        results = []
        for i in range(6):
            # Wait for valid each step (max 18 cycles per step)
            for _ in range(50):
                if dut.valid.value == 1: 
                    results.append(int(dut.area.value))
                    await RisingEdge(dut.clk)
                    break
                await RisingEdge(dut.clk)
            else:
                break

        # Compare results (only expected steps)
        success = True
        for i in range(len(test["expected"])):
            if i >= len(results):
                dut._log.error("Missing output areas")
                success = False
                break
            if test["expected"][i] != results[i]:
                dut._log.error(f"Area mismatch step {i}: {results[i]/10} vs {test["expected"][i]/10}")
                success = False

        if success and dut.done.value == 1:
            passed += 1

        await ClockCycles(dut.clk, 10)

    dut._log.info(f"{passed}/{len(tests)} tests passed")