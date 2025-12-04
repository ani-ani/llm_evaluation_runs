import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_permutation(dut):
    test_cases = [
        # (N, A, B, valid, expected_perm[:8])
        (4, 2, 2, True, [2,1,4,3,0,0,0,0]),
        (5, 2, 3, True, [2,1,4,5,3,0,0,0]),
        (3, 2, 2, False, [0]*8),
        (6, 3, 3, True, [2,3,1,5,6,4,0,0]),
        (1, 1, 1, True, [1,0,0,0,0,0,0,0])
    ]
    
    passed = 0
    for tc in test_cases:
        n, a, b, expected_valid, expected = tc
        dut.N.value = n
        dut.A.value = a
        dut.B.value = b
        await Timer(1, 'ns')
        
        if dut.valid.value != expected_valid:
            dut._log.error(f"N={n} A={a} B={b}: Valid expected {expected_valid}, got {dut.valid.value}")
            continue
        
        if not expected_valid:
            passed += 1
            continue
        
        # Extract 8 elements from 32-bit packed signal
        actual = []
        for i in range(8):
            actual.append((dut.perm.value >> (i*4)) & 0xF)
        
        # Check only first N elements
        valid = True
        for i in range(n):
            if actual[i] != expected[i]:
                dut._log.error(f"Elem {i+1} mismatch: Got {actual[i]}, Expected {expected[i]}")
                valid = False
        
        if valid:
            passed += 1
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")