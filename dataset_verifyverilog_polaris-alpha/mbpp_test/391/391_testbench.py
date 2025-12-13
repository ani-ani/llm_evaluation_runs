import cocotb
from cocotb.triggers import Timer

def pad_string(s, length):
    return s.ljust(length)[:length]

def str_to_int(s):
    val = 0
    for c in s:
        val = (val << 8) | ord(c)
    return val

@cocotb.test()
async def test_list_to_dict(dut):
    test_cases = [
        (["S001", "S002", "S003", "S004"],
         ["Adina Park", "Leyton Marsh", "Duncan Boyle", "Saim Richards"],
         [85, 98, 89, 92]),
        (["abc", "def", "ghi", "jkl"],
         ["python", "program", "language", "programs"],
         [100, 200, 300, 400]),
        (["A1", "A2", "A3", "A4"],
         ["java", "C", "C++", "DBMS"],
         [10, 20, 30, 40])
    ]

    passed = 0
    for l1, l2, l3 in test_cases:
        l1_pad = [pad_string(s,4) for s in l1]
        l2_pad = [pad_string(s,16) for s in l2]
        
        # Apply inputs
        for i in range(4):
            dut.key1[i].value = str_to_int(l1_pad[i])
            dut.key2[i].value = str_to_int(l2_pad[i])
            dut.value[i].value = l3[i]
        
        await Timer(1, units='ns')
        
        # Verify outputs
        correct = True
        for i in range(4):
            k1 = dut.key1_out[i].value
            k2 = dut.key2_out[i].value
            val = dut.value_out[i].value
            
            if k1 != str_to_int(l1_pad[i]):
                dut._log.error(f"Index {i}: key1_out={k1} != {str_to_int(l1_pad[i])}")
                correct = False
            if k2 != str_to_int(l2_pad[i]):
                dut._log.error(f"Index {i}: key2_out={k2} != {str_to_int(l2_pad[i])}")
                correct = False
            if val != l3[i]:
                dut._log.error(f"Index {i}: value_out={val} != {l3[i]}")
                correct = False
        
        if correct:
            passed += 1
            dut._log.info("Passed test case")
        else:
            dut._log.error("Failed test case")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")