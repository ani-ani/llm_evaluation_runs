import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

def float_to_q16(f):
    return int(f * (1 << 16)) & 0xFFFFFFFF

@cocotb.test()
async def test_boar_charge(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (SCALED VALUES - original/sample adapted to 16-bit)
    test_cases = [
        # Test Case 1: Sample Input 1 (1 tree)
        {
            "tree_count": 1, "b": 1<<12, "d": 4<<12,  # (1,4) scaled<<12
            "trees": [(3<<12, 0<<12, 1<<12)], # (3,0,1) scaled<<12
            "expected": 0.76772047
        },
        # Test Case 2: Sample Input 2 (4 trees)
        {
            "tree_count": 4, "b": 1<<12, "d": 3<<12,
            "trees": [
                (6<<12, 0<<12, 3<<12),
                (0<<12,6<<12, 3<<12),
                (-6<<12,0<<12, 3<<12),
                (0<<12,-6<<12, 3<<12)
            ],
            "expected": 0.19253205
        }
    ]

    passed = 0
    for case in test_cases:
        # Apply reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load inputs
        dut.start.value = 0
        dut.tree_count.value = case["tree_count"]
        dut.b.value = case["b"]
        dut.d.value = case["d"]
        for i in range(8):
            if i < case["tree_count"]:
                dut.tree_x[i].value = case["trees"][i][0]
                dut.tree_y[i].value = case["trees"][i][1]
                dut.tree_r[i].value = case["trees"][i][2]
            else:
                dut.tree_x[i].value = 0
                dut.tree_y[i].value = 0
                dut.tree_r[i].value = 0
        
        # Start calculation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (25 cycles)
        for _ in range(30):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check result (allow 0.1% relative error)
        expected_q16 = float_to_q16(case["expected"])
        actual = dut.prob_q16.value
        tolerance = int(case["expected"] * (1 << 16) * 0.001)
        
        if abs(actual - expected_q16) <= tolerance:
            passed += 1
        else:
            actual_float = actual / (1 << 16)
            dut._log.error(f"Test failed: Expected {case['expected']} ({hex(expected_q16)}), got {actual_float} ({hex(actual)}). Diff: {abs(actual - expected_q16)} > {tolerance}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)