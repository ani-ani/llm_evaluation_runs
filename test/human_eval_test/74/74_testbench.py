import cocotb
from cocotb.triggers import Timer
import random

def pack_lengths(str_lens):
    """Convert list of string lengths to 64-bit packed format"""
    padded = str_lens + [0]*(8 - len(str_lens))
    return sum(v << (56 - 8*i) for i, v in enumerate(padded[:8]))

@cocotb.test()
async def test_list_char_compare(dut):
    # Adapted test cases (original strings converted to length arrays)
    test_cases = [
        ([], [], 0, 0, 0),  # Both empty
        ([2,5], [2,2], 7, 4, 1),  # ['hi','admin'] vs ['hI','Hi']
        ([2,5], [2,2,5,7], 7, 16, 0),  # ['hi','admin'] vs ['hi','hi','admin','project']
        ([1], [1,1,1,1,1], 1, 5, 0),  # ['4'] vs ['1','2','3','4','5']
        ([2,5], [2], 7, 2, 1),  # Edge case: [] vs ['this']
        ([], [4], 0, 4, 0),  # Original edge case
    ]
    
    passed = 0
    for case in test_cases:
        lst1, lst2, exp_t1, exp_t2, exp_sel = case
        dut.lst1.value = pack_lengths(lst1)
        dut.lst2.value = pack_lengths(lst2)
        await Timer(1, 'ns')
        
        t1 = dut.total1.value.integer
        t2 = dut.total2.value.integer
        sel = dut.list_sel.value.integer
        
        if t1 == exp_t1 and t2 == exp_t2 and sel == exp_sel:
            passed += 1
            dut._log.info(f"PASS: {lst1} vs {lst2} => sel={sel}, totals={t1}/{t2}")
        else:
            dut._log.error(f"FAIL: {lst1} vs {lst2} => got sel={sel}, totals={t1}/{t2} (expected sel={exp_sel}, totals={exp_t1}/{exp_t2})")
    
    dut._log.info(f"TEST SUMMARY: {passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), "Some test cases failed"