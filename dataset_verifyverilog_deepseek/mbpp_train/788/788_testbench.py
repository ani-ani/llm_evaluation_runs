import cocotb
from cocotb.triggers import Timer

def str_to_bin(s):
    return int.from_bytes(s.encode() + b'\x00'*(16-len(s)), 'little')

def verify_tuple(dut, expected):
    for i,v in enumerate(expected):
        value = dut.tuple_out[i].value.integer
        recv_str = bytes([(value >> (8*j)) & 0xff for j in range(16)]).decode('utf-8').split('\x00')[0]
        assert recv_str == v, f"Element {i} mismatch: {recv_str} vs {v}"

@cocotb.test()
async def test_tuple_creator(dut):
    test_cases = [
        (["WEB", "is"], "best", ['WEB','is','best']),
        (["We", "are"], "Developers", ['We','are','Developers']),
        (["Part", "is"], "Wrong", ['Part','is','Wrong'])
    ]
    passed = 0
    
    for lst, s, expected in test_cases:
        # Convert inputs to 128-bit values
        dut.test_list[0].value = str_to_bin(lst[0])
        dut.test_list[1].value = str_to_bin(lst[1])
        dut.test_str.value = str_to_bin(s)
        
        await Timer(1, units='ns')
        
        try:
            verify_tuple(dut, expected)
            passed += 1
            dut._log.info(f"PASS: {lst} + '{s}' -> {expected}")
        except AssertionError as e:
            dut._log.error(f"FAIL: {e}")
    
    dut._log.info(f"Test summary: {passed}/{len(test_cases)} passed")
    assert passed == len(test_cases)