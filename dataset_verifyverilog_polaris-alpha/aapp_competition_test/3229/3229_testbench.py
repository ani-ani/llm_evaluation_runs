import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

@cocotb.test()
async def test_worst_rank(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (scaled to 4 contestants max)
    test_cases = [
        # Test case 1: Original Input 1 (4 contests, 2 contestants)
        {
            'num_contestants': 2,
            'num_contests': 4,
            'scores': [
                [50, 50, 75, 0],
                [25, 25, 25, 0],
                [0, 0, 0, 0],
                [0, 0, 0, 0]
            ],
            'expected': 2
        },
        # Test case 2: Original Input 2 (5 contests -> reduced to 4)
        {
            'num_contestants': 2,
            'num_contests': 4,
            'scores': [
                [50, 50, 50, 50],
                [25, 25, 25, 25],
                [0, 0, 0, 0],
                [0, 0, 0, 0]
            ],
            'expected': 1
        },
        # Test case 3: Original Input 3 (2 contests, 4 contestants)
        {
            'num_contestants': 4,
            'num_contests': 2,
            'scores': [
                [90, 0, 0, 0],
                [1, 0, 0, 0],
                [3, 0, 0, 0],
                [2, 0, 0, 0]
            ],
            'expected': 3
        }
    ]

    passed = 0
    for case in test_cases:
        # Reset
        dut.rst_n.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load inputs
        dut.num_contestants.value = case['num_contestants']
        dut.num_contests.value = case['num_contests']
        for i in range(4):
            for j in range(4):
                dut.scores[i][j].value = case['scores'][i][j]

        # Wait for computation
        await ClockCycles(dut.clk, 10)
        if not dut.done.value:
            raise cocotb.result.TestFailure("Computation timed out")

        # Check result
        if dut.worst_rank.value == case['expected']:
            passed += 1
        else:
            dut._log.error(f"Test failed: Expected {case['expected']}, got {dut.worst_rank.value}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")