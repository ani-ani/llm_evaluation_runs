import cocotb
from cocotb.triggers import RisingEdge, Timer, ClockCycles
from cocotb.clock import Clock

async def apply_reset(dut):
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_min_k(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # ASCII mapping: A=0x41, B=0x42, ...
    test_cases = [
        # Test 1: Original "Manjeet" simplified to 'M', 'A', 'a', 'N'
        {
            'names':  [0x4D, 0x41, 0x61, 0x4E],  # M, A, a, N
            'scores': [10, 4, 2, 8],
            'K': 2,
            'exp_names': [0x61, 0x41, 0, 0],     # a, A
            'exp_scores': [2, 4, 0, 0]
        },
        # Test 2
        {
            'names':  [0x53, 0x41, 0x61, 0x4E], # S, A, a, N
            'scores': [11, 5, 3, 9],
            'K': 3,
            'exp_names': [0x61, 0x41, 0x4E, 0], # a, A, N
            'exp_scores': [3, 5, 9, 0]
        },
        # Test 3
        {
            'names':  [0x74, 0x41, 0x61, 0x53], # t, A, a, S
            'scores': [14, 11, 9, 16],
            'K': 1,
            'exp_names': [0x61, 0, 0, 0],       # a
            'exp_scores': [9, 0, 0, 0]
        },
        # Edge case: K=0
        {
            'names':  [0x41, 0x42, 0x43, 0x44],
            'scores': [1, 2, 3, 4],
            'K': 0,
            'exp_names': [0, 0, 0, 0],
            'exp_scores': [0, 0, 0, 0]
        }
    ]

    passed = 0
    await apply_reset(dut)
    dut.start.value = 0

    for case in test_cases:
        # Load inputs
        for i in range(4):
            dut.names[i].value = case['names'][i]
            dut.scores[i].value = case['scores'][i]
        dut.K.value = case['K']

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (20 cycles worst-case)
        await ClockCycles(dut.clk, 25)

        # Check outputs
        match = True
        for i in range(4):
            if dut.min_names[i].value != case['exp_names'][i] or \
               dut.min_scores[i].value != case['exp_scores'][i]:
                match = False

        if match and dut.done.value == 1:
            passed += 1
            dut._log.info(f"PASS: K={case['K']}")
        else:
            dut._log.error(f"FAIL: K={case['K']}"+
                f"
  Got: names={[dut.min_names[i].value for i in range(4)]}"+
                f" scores={[dut.min_scores[i].value for i in range(4)]}"+
                f"
  Exp: names={case['exp_names']} scores={case['exp_scores']}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)