import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_transposer(dut):
    test_sets = [
        # Test 1: Original Python test case 1
        {
            'input': [['x', 'y', 0, 0], ['a', 'b', 0, 0], ['m', 'n', 0, 0], [0]*4],
            'expected': [['x", "a", "m", 0], ['y", "b", "n", 0], [0]*4, [0]*4],
            'comment': "3 sublists with 2 elements each"
        },
        # Test 2: Original Python test case 2 (numbers to Unicode conversion)
        {
            'input': [[1, 2, 0, 0], [3, 4, 0, 0], [5, 6, 0, 0], [7, 8, 0, 0]],
            'expected': [[1, 3, 5, 7], [2, 4, 6, 8], [0]*4, [0]*4],
            'comment': "4 sublists with 2 numbers each"
        },
        # Test 3: Modified version of Python test case 3
        {
            'input': [['x', 'y', 'z', 0], ['a', 'b', 'c', 0], ['m', 'n', 'o', 0], [0]*4],
            'expected': [['x", "a", "m", 0], ['y", "b", "n", 0], ['z", "c", 'o', 0], [0]*4],
            'comment': "3 sublists with 3 elements each"
        },
        # Test 4: Edge case - empty lists
        {
            'input': [[0,0,0,0]]*4,
            'expected': [[0]*4]*4,
            'comment': "All-zero input"
        }
    ]

    passed = 0
    for test_id, test_data in enumerate(test_sets):
        # Set inputs
        for j in range(4):
            for i in range(4):
                val = test_data['input'][j][i]
                # Convert characters to ASCII
                if isinstance(val, str):
                    dut.arr_in[j][i].value = ord(val)
                else:
                    dut.arr_in[j][i].value = val
        
        # Allow signals to propagate (combinational logic)
        await Timer(1, units='ns')

        # Check outputs
        correct = True
        for i in range(4):
            for j in range(4):
                expected_val = test_data['expected'][i][j]
                hw_val = dut.arr_out[i][j].value
                
                # Convert expected string characters to ASCII
                if isinstance(expected_val, str):
                    expected_val = ord(expected_val)
                
                # Compare
                if hw_val != expected_val:
                    dut._log.error(f"Test {test_id} {test_data['comment']} FAILED at output[{i}][{j}]: "
                                  f"Got {'' + chr(hw_val) + '' if hw_val < 128 else hw_val}, "
                                  f"Expected {'' + chr(expected_val) + '' if isinstance(test_data['expected'][i][j], str) else expected_val}")
                    correct = False

        if correct:
            passed += 1
            dut._log.info(f"Test {test_id} PASSED")
        
    dut._log.info(f"{passed}/{len(test_sets)} tests passed")