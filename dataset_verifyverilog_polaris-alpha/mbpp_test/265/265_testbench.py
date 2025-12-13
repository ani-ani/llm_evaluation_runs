import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_splitter(dut):
    passed = 0
    # Test 1: Characters (ASCII values), step=3
    chars = [ord(c) for c in ['a','b','c','d','e','f','g','h']]
    expected1 = [
        [ord('a'), ord('d')],
        [ord('b'), ord('e')],
        [ord('c'), ord('f')],
        [0, 0]  # Unused sublist
    ]
    # Test 2: Integers 1-8, step=2
    nums = list(range(1,9))
    expected2 = [
        [1, 3, 5, 7],
        [2, 4, 6, 8],
        [0, 0],
        [0, 0]
    ]
    # Test 3: Edge case - step=4, short list
    edge_data = [10,20,30,40,0,0,0,0]
    expected3 = [
        [10, 0],
        [20, 0],
        [30, 0],
        [40, 0]
    ]
    tests = [
        (chars, 3, expected1),
        (nums, 2, expected2),
        (edge_data, 4, expected3)
    ]
    for data, step, expected in tests:
        # Apply inputs
        for i in range(8):
            dut.data[i].value = data[i]
        dut.step.value = step
        await Timer(1, units='ns')
        # Check outputs
        result = []
        flat = dut.sublists.value
        # Reconstruct 4×2 array from 64-bit output
        for i in range(4):
            sublist = [
                (flat >> (8*(i*2 + 1))) & 0xFF,
                (flat >> (8*(i*2))) & 0xFF
            ]
            result.append(sublist)
        # Validate only first 'step' sublists
        valid = True
        for i in range(step):
            for j in range(2):
                hw_val = result[i][j].integer
                exp = expected[i][j] if j < len(expected[i]) else 0
                if hw_val != exp:
                    dut._log.error(f"Mismatch at sublist[{i}][{j}]: {hw_val} vs {exp}")
                    valid = False
        if valid:
            passed += 1
            dut._log.info(f"Passed test: step={step}")
        else:
            dut._log.error(f"Failed test: step={step}")
    dut._log.info(f"{passed}/{len(tests)} tests passed")