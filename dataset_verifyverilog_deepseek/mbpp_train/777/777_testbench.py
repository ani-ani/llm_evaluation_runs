import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_sum_non_repeated(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases (adapted to 16-element max)
    test_cases = [
        {"arr": [1,2,3,1,1,4,5,6], "expected": 21, "len": 8},
        {"arr": [1,10,9,4,2,10,10,45,4], "expected": 71, "len": 9},
        {"arr": [12,10,9,45,2,10,10,45,10], "expected": 78, "len": 9},
        {"arr": [7,7,7,7], "expected": 0, "len": 4},
        {"arr": [100,200,300], "expected": 600, "len": 3}
    ]

    passed = 0
    for case in test_cases:
        # Initialize inputs
        for i in range(16):
            dut.data[i].value = case["arr"][i] if i < case["len"] else 0
        dut.length.value = case["len"]

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (20 cycles)
        await ClockCycles(dut.clk, 20)
        
        # Check results
        if dut.done.value == 1 and dut.sum.value == case["expected"]:
            dut._log.info(f"PASS: arr={case['arr']} sum={dut.sum.value}")
            passed += 1
        else:
            dut._log.error(f"FAIL: Test {case['arr']}
"
                          f"  Got={dut.sum.value} Expected={case['expected']}
"
                          f"  done={dut.done.value}")
        
        # Insert pause between tests
        await ClockCycles(dut.clk, 2)

    # Report results
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    if passed != total:
        raise cocotb.result.TestFailure("Some tests failed")