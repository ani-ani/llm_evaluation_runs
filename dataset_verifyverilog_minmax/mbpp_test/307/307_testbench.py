import cocotb
from cocotb.triggers import Timer
@cocotb.test()
async def test_tuple_mod(dut):
    tests = [
        # (input_tuple, m, n, expected_tuple)
        # Test 1: Original test case - m=2, n=50
        (("HELLO", 5, 0, 1, True), 2, 50, ("HELLO", 5, 50, 0, True)),
        # Test 2: m=2, n=100
        (("HELLO", 5, 0, 1, True), 2, 100, ("HELLO", 5, 100, 0, True)),
        # Test 3: m=2, n=500
        (("HELLO", 5, 0, 1, True), 2, 500, ("HELLO", 5, 500, 0, True)),
        # Edge case: m=0 (no change)
        (("TEST", 10, 5, 0, False), 0, 100, ("TEST", 10, 5, 0, False))
    ]
    passed = 0
    for (text, num, list_v, list_empty, bool_in), m, n, (exp_text, exp_num, exp_list, exp_le, exp_bool) in tests:
        # Convert "HELLO" to 5-byte ASCII
        text_bytes = sum(ord(c) << (8*i) for i,c in enumerate(text.ljust(5)[:5]))
        exp_bytes = sum(ord(c) << (8*i) for i,c in enumerate(exp_text.ljust(5)[:5]))
        
        dut.str_field.value = text_bytes
        dut.num_field.value = num
        dut.list_val.value = list_v
        dut.list_empty.value = list_empty
        dut.bool_field.value = bool_in
        dut.m.value = m
        dut.n.value = n
        await Timer(1, "ns")
        
        failed = False
        if dut.str_out.value != exp_bytes:
            dut._log.error(f"STR FAIL: Got {dut.str_out.value:x}, exp {exp_bytes:x}")
            failed = True
        if dut.num_out.value != exp_num:
            dut._log.error(f"NUM FAIL: Got {dut.num_out.value}, exp {exp_num}")
            failed = True
        if m == 2 and list_empty == 1:  # Special check for list append
            if dut.list_out.value != n or dut.list_valid_out.value != 0:
                dut._log.error(f"LIST FAIL: Got value={dut.list_out.value}/valid={dut.list_valid_out.value}, exp {n}/0")
                failed = True
        else:
            if dut.list_out.value != exp_list or dut.list_valid_out.value != exp_le:
                dut._log.error(f"LIST FAIL: Got {dut.list_out.value}/{dut.list_valid_out.value}, exp {exp_list}/{exp_le}")
                failed = True
        if dut.bool_out.value != exp_bool:
            dut._log.error(f"BOOL FAIL: Got {dut.bool_out.value}, exp {exp_bool}")
            failed = True
        
        if not failed:
            passed += 1
            dut._log.info(f"Passed case: m={m}, n={n}")
    
    dut._log.info(f"RESULT: {passed}/{len(tests)} tests passed")