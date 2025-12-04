import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_pluck(dut):
    def pad(arr):
        return arr + [255]*(8 - len(arr))  # Pad with odd values

    test_cases = [
        (pad([4,2,3]),     [2, 1, 1]),
        (pad([1,2,3]),     [2, 1, 1]),
        (pad([]),          [0, 0, 0]),   # Empty case
        (pad([5,0,3,0,4,2]), [0, 1, 1]),
        (pad([1,2,3,0,5,3]), [0, 3, 1]),
        (pad([5,4,8,4,8]),   [4, 1, 1]),
        (pad([7,6,7,1]),     [6, 1, 1]),
        (pad([7,9,7,1]),     [0, 0, 0])  # No evens
    ]

    passed = 0
    for nodes, expected in test_cases:
        # Apply inputs
        for i, val in enumerate(nodes):
            dut.nodes[i].value = val
        
        await Timer(1, 'ns')  # Comb logic settling
        
        # Extract outputs
        res_valid = int(dut.valid.value)
        res_value = int(dut.value.value)
        res_idx = int(dut.index.value)
        
        # Check if empty case
        if expected[2] == 0:
            if res_valid == 0:
                passed += 1
                dut._log.info(f"PASS: {nodes} => []")
            else:
                dut._log.error(f"FAIL: {nodes} => [{res_value},{res_idx}], expected []")
        else:
            if res_valid and (res_value, res_idx) == tuple(expected[:2]):
                passed += 1
                dut._log.info(f"PASS: {nodes} => [{res_value},{res_idx}]")
            else:
                dut._log.error(f"FAIL: {nodes} => [{res_value},{res_idx}], expected {expected[:2]}")
    
    dut._log.info(f"TEST SUMMARY: {passed}/{len(test_cases)} tests passed")