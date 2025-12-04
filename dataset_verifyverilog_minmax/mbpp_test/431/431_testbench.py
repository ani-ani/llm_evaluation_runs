import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_common(dut):
    test_cases = [
        # Test 1: Matching element 5 (True)
        ([1,2,3,4,5]+[0]*3, [1,1,1,1,1]+[0]*3,
         [5,6,7,8,9]+[0]*3, [1,1,1,1,1]+[0]*3, 1),
        
        # Test 2: No overlap (False)
        ([1,2,3,4,5]+[0]*3, [1,1,1,1,1]+[0]*3,
         [6,7,8,9]+[0]*4, [1,1,1,1]+[0]*4, 0),
        
        # Test 3: Character 'b' match (0x62)
        ([0x61,0x62,0x63]+[0]*5, [1,1,1]+[0]*5,
         [0x64,0x62,0x65]+[0]*5, [1,1,1]+[0]*5, 1),
        
        # Edge case: All elements invalid
        ([255]*8, [0]*8,
         [255]*8, [0]*8, 0)
    ]
    passed = 0
    
    for (l1, v1, l2, v2, expected) in test_cases:
        # Flatten arrays for Verilog input
        for i in range(8):
            dut.list1[i].value = l1[i]
            dut.list1_valid.value = LogicArray(v1)
            dut.list2[i].value = l2[i]
            dut.list2_valid.value = LogicArray(v2)
        
        await Timer(1, 'ns')
        
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: {l1[:5]} vs {l2[:5]} → {expected}")
        else:
            dut._log.error(f"FAIL: {l1[:5]} vs {l2[:5]} → {dut.result.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")