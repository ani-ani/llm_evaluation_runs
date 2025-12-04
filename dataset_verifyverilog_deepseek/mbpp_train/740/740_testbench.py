import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_tuple_to_dict(dut):
    test_cases = [
        # (a,b,c,d,e,f) => (k1,v1,k2,v2,k3,v3)
        (1,5,7,10,13,5, {1:5, 7:10, 13:5}),
        (1,2,3,4,5,6, {1:2, 3:4, 5:6}),
        (7,8,9,10,11,12, {7:8, 9:10, 11:12})
    ]
    passed = 0
    
    for a,b,c,d,e,f,expected in test_cases:
        dut.a.value = a
        dut.b.value = b
        dut.c.value = c
        dut.d.value = d
        dut.e.value = e
        dut.f.value = f
        await Timer(1, units='ns')
        
        results = {
            int(dut.key1.value): int(dut.val1.value),
            int(dut.key2.value): int(dut.val2.value),
            int(dut.key3.value): int(dut.val3.value)
        }
        
        if results == expected:
            passed += 1
            dut._log.info(f"PASS: Input {a},{b},{c},{d},{e},{f} => {results}")
        else:
            dut._log.error(f"FAIL: Input {a},{b},{c},{d},{e},{f}
  Expected: {expected}
  Got:      {results}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    if passed < len(test_cases):
        raise TestFailure("Some tests failed")