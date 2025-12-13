import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_unicyclic(dut):
    # Test cases adapted for V=4 max
    test_cases = [
        # Sample Input 1 (V=4, E=5)
        {"V": 4, "E": 5, "edges": [[1,2],[1,3],[2,3],[1,4],[2,4]], "expected": 5},
        # Sample Input 2 (V=4, E=2) - disconnected
        {"V": 4, "E": 2, "edges": [[1,2],[3,4]], "expected": 0},
        # Additional test case: triangle + 1 edge (V=4, E=4)
        {"V": 4, "E": 4, "edges": [[1,2],[2,3],[1,3],[1,4]], "expected": 3}
    ]

    passed = 0
    for case in test_cases:
        # Convert edge list to packed format
        edge_packed = 0
        for i, (a, b) in enumerate(case['edges']):
            edge_packed |= (a << (i*4 + 0)) | (b << (i*4 + 2))

        dut.V.value = case['V']
        dut.E.value = case['E']
        dut.edge_list.value = edge_packed
        await Timer(100, units='ns')  # Allow time for combinatorial logic

        if dut.cycle_count.value == case['expected']:
            passed += 1
        else:
            dut._log.error(f"Test failed: V={case['V']} E={case['E']} Edges={case['edges']}
            Expected {case['expected']} Got {int(dut.cycle_count.value)}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")