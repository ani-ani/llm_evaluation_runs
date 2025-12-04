import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_sorter(dut):
    passed = 0
    total = 4
    
    # Test 1: All length 2 (same scores)
    dut.n.value = 3
    dut.len0.value = 2; dut.seq0.value = 0b01010000  # PP
    dut.len1.value = 2; dut.seq1.value = 0b00000000  # RR
    dut.len2.value = 2; dut.seq2.value = 0b01100000  # PS
    dut.len3.value = 2; dut.seq3.value = 0b10100000  # SS
    await Timer(1, 'ns')
    try:
        assert dut.sorted_indices[0].value == 0, "Test1 index0 fail"
        assert dut.sorted_indices[1].value == 1, "Test1 index1 fail"
        assert dut.sorted_indices[2].value == 2, "Test1 index2 fail"
        assert dut.sorted_indices[3].value == 3, "Test1 index3 fail"
        passed += 1
    except AssertionError as e:
        dut._log.error(str(e))
    
    # Test 2: Mixed lengths (different scores)
    dut.n.value = 4
    dut.len0.value = 1; dut.seq0.value = 0b01000000  # P (len1)
    dut.len1.value = 2; dut.seq1.value = 0b00000000  # RR (len2)
    dut.len2.value = 3; dut.seq2.value = 0b10000000  # S__ (len3)
    dut.len3.value = 4; dut.seq3.value = 0b01011000  # PPSP (len4)
    await Timer(1, 'ns')
    try:
        assert dut.sorted_indices[0].value == 0, "Test2 index0 fail (expected highest score)"
        assert dut.sorted_indices[1].value == 1
        assert dut.sorted_indices[2].value == 2
        assert dut.sorted_indices[3].value == 3
        passed += 1
    except AssertionError as e:
        dut._log.error(str(e))
    
    # Test 3: Partial used (len=0 indicates unused)
    dut.n.value = 5
    dut.len0.value = 4; dut.seq0.value = 0b01010000  # PP..
    dut.len1.value = 4; dut.seq1.value = 0b00000000  # RR..
    dut.len2.value = 0; dut.seq2.value = 0
    dut.len3.value = 3; dut.seq3.value = 0b10100000  # SS.
    await Timer(1, 'ns')
    try:
        # 3rd sequence (index3) should come after 0 and 1 (score=15 vs score=6)
        assert (dut.sorted_indices[0].value in [0,1]) and (dut.sorted_indices[1].value in [0,1]), "Test3 order fail"
        assert dut.sorted_indices[2].value == 3, "Test3 index2 fail"
        assert dut.sorted_indices[3].value == 2, "Test3 unused not last"
        passed += 1
    except AssertionError as e:
        dut._log.error(str(e))
    
    # Test 4: Tie-breaker (same score, preserve order)
    dut.n.value = 8
    dut.len0.value = 4; dut.len1.value = 4; dut.len2.value=4; dut.len3.value=0
    await Timer(1, 'ns')
    try:
        assert dut.sorted_indices[0].value == 0
        assert dut.sorted_indices[1].value == 1
        assert dut.sorted_indices[2].value == 2
        passed += 1
    except AssertionError as e:
        dut._log.error(str(e))
    
    dut._log.info(f"{passed}/{total} tests passed")