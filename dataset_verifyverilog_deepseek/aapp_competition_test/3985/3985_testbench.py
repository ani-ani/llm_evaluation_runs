import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_max_ops(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (scaled original examples)
    test_data = [
        # Original: 3 elements, 2 pairs [8,3,8] => 0
        {
            'n': 3, 'm': 2,
            'arr': [8, 3, 8, 0],
            'pairs': [(1,2), (2,3)], # Original indices converted to 0-based
            'expected': 0
        },
        # Original: 3 elements, 2 pairs [8,12,8] => 2
        {
            'n': 3, 'm': 2,
            'arr': [8, 12, 8, 0],
            'pairs': [(1,2), (2,3)],
            'expected': 2
        },
        # Custom: 4 elements, 2 identical pairs
        {
            'n': 4, 'm': 2,
            'arr': [16, 16, 16, 16],
            'pairs': [(1,2), (3,4)],
            'expected': 8  # 2 pairs * 4 factors (16=2^4)
        },
        # Edge case: minimum elements
        {
            'n': 2, 'm': 1,
            'arr': [4, 4, 0, 0],
            'pairs': [(1,2)],
            'expected': 2  # 4=2^2
        },
        # No valid operations
        {
            'n': 2, 'm': 1,
            'arr': [3, 5, 0, 0],
            'pairs': [(1,2)],
            'expected': 0
        }
    ]

    passed = 0
    for test in test_data:
        # Reset module
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load inputs
        dut.arraysize.value = test['n'] - 1  # Store as 0-based count (0=1 element)
        dut.paircount.value = test['m'] 
        for i in range(4):
            getattr(dut, f'array{i+1}').value = test['arr'][i]
        for p in range(4):
            if p < len(test['pairs']):
                i,j = test['pairs'][p]
                getattr(dut, f'pair{p+1}_i').value = i-1  # Convert to 0-based index
                getattr(dut, f'pair{p+1}_j').value = j-1
            else:
                getattr(dut, f'pair{p+1}_i').value = 0
                getattr(dut, f'pair{p+1}_j').value = 0

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (max 20 cycles)
        timeout = 20
        while timeout > 0 and not dut.done.value:
            await RisingEdge(dut.clk)
            timeout -= 1

        # Check result
        if timeout == 0:
            dut._log.error("Test timed out")
        elif dut.result.value == test['expected']:
            passed += 1
        else:
            dut._log.error(f"Test failed: Expected {test['expected']}, got {dut.result.value}
Data: {test}")

        await RisingEdge(dut.clk)
    dut._log.info(f"{passed}/{len(test_data)} tests passed")
