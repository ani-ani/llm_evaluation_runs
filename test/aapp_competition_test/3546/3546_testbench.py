import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_theorem_dag(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Original Sample Input (adapted)
    # Input:
    # 2
    # 2
    # 10 0
    # 3 1 1
    # 1
    # 4 1 0
    test_input = {
        'num_theorems': 2,
        'num_proofs': [2, 1, 0, 0],
        'proof_lengths': [
            [10, 3] + [0]*8,  # Thm0 proofs [10,3]
            [4] + [0]*9,     # Thm1 proofs [4]
            [0]*10,
            [0]*10,
        ],
        'num_deps': [
            [0,1] + [0]*8,  # Thm0: proof0 has 0 deps, proof1 has 1 dep
            [1] + [0]*9,    # Thm1: proof0 has 1 dep
            [0]*10,
            [0]*10,
        ],
        'deps': [
            [[], [1]] + [[]]*8,  # Thm0 proof1 depends on thm1
            [[0]] + [[]]*9,     # Thm1 proof0 depends on thm0
            [[]]*10,
            [[]]*10
        ],
        'expected': 10  # Choose proof0 (requires no deps)
    }

    # Test Case 2: Provided complex example (scaled)
    test_input2 = {
        'num_theorems': 4,
        'num_proofs': [2, 1, 1, 2],
        'proof_lengths': [
            [1, 5] + [0]*8,      # Thm0
            [2] + [0]*9,         # Thm1
            [0] + [0]*9,         # Thm2
            [2, 1] + [0]*8       # Thm3
        ],
        'num_deps': [
            [2,1] + [0]*8,       # Thm0 proof0 has 2 deps, proof1 has 1 dep
            [0] + [0]*9,         # Thm1: no deps
            [0] + [0]*9,\
            [0,1] + [0]*8        # Thm3 proof1 has 1 dep
        ],
        'deps': [
            [[1,3], [2]] + [[]]*8, # Thm0 proof0 depends on 1,3; proof1 on 2
            [[]] + [[]]*9,\
            [[]] + [[]]*9,\
            [[], [1]] + [[]]*8   # Thm3 proof1 depends on 1
        ],
        'expected': 4  # Path computations will yield 4
    }

    tests = [test_input, test_input2]
    passed = 0

    for i, test in enumerate(tests):
        # Apply inputs
        dut.num_theorems.value = test['num_theorems']
        for thm in range(4):
            dut.num_proofs[thm].value = test['num_proofs'][thm]
            for proof in range(10):
                dut.proof_lengths[thm][proof].value = test['proof_lengths'][thm][proof]
                dut.num_deps[thm][proof].value = test['num_deps'][thm][proof]
                for dep in range(3):
                    if dep < len(test['deps'][thm][proof]):
                        dut.deps[thm][proof][dep].value = test['deps'][thm][proof][dep]
                    else:
                        dut.deps[thm][proof][dep].value = 0

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait until done
        for _ in range(10):  # Max wait 10 cycles
            await RisingEdge(dut.clk)
            if dut.done.value:
                break

        # Check result
        result = int(dut.min_length.value)
        if result == test['expected']:
            passed += 1
            dut._log.info(f"Test {i} passed: {result} == {test['expected']}")
        else:
            dut._log.error(f"Test {i} FAILED: {result} != {test['expected']}")

        # Reset between tests (optional)
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    dut._log.info(f"{passed}/{len(tests)} tests passed")