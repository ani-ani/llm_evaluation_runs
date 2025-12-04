import cocotb
from cocotb.triggers import Timer
import struct

def float_to_q16_16(val):
    if val == "IMPOSSIBLE":
        return 0xFFFFFFFF
    int_part = int(val)
    frac_part = int((val - int_part) * 65536)
    return (int_part << 16) | frac_part

@cocotb.test()
async def test_escape(dut):
    test_cases = [
        # Test case 1 (IMPOSSIBLE)
        {
            'n': 3, 'e': 1, 'exits': 1<<0,
            'roads': [
                [0,7,0,0], [7,0,8,0], [0,8,0,0], [0,0,0,0]
            ],
            'b_start': 2, 'p_start': 1,
            'expected': float('inf')
        },
        # Test case 2 (74.666... km/h)
        {
            'n': 3, 'e': 1, 'exits': 1<<0,
            'roads': [
                [0,7,0,0], [7,0,8,0], [0,8,0,0], [0,0,0,0]
            ],
            'b_start': 1, 'p_start': 2,
            'expected': 74.6666666667
        },
        # Test case 3 (137.142... km/h)
        {
            'n': 4, 'e': 2, 'exits': (1<<0)|(1<<1),
            'roads': [
                [0,0,4,1], [0,0,30,0], [4,30,0,10], [1,0,10,0]
            ],
            'b_start': 2, 'p_start': 3,
            'expected': 137.142857143
        }
    ]
    passed = 0
    for case in test_cases:
        dut.n.value = case['n'] - 1  # 0-indexed
        dut.e.value = case['e']
        dut.exits.value = case['exits']
        for i in range(4):
            for j in range(4):
                dut.roads[i][j].value = case['roads'][i][j]
        dut.b_start.value = case['b_start'] - 1
        dut.p_start.value = case['p_start'] - 1
        await Timer(10, units='ns')  # Processing time
        
        result = dut.min_speed.value
        if case['expected'] == float('inf'):
            if result == 0xFFFFFFFF:
                passed +=1
            else:
                dut._log.error("IMPOSSIBLE case failed. Got %08x" % result)
        else:
            expected_q = float_to_q16_16(case['expected'])
            if abs(result - expected_q) < 655:  # 0.01 tolerance in float
                passed +=1
            else:
                repacked = struct.pack('I', result)
                actual_float = struct.unpack('f', repacked)[0]
                dut._log.error("Failed case: expected %.4f got %.4f" % (case['expected'], actual_float))
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))
