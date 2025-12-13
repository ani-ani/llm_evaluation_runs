import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_sliding_blocks(dut):
    test_cases = [
        # Test 1: Valid small configuration
        {'init': (0,0), 'targets': [(0,1),(1,1),(1,2),(2,2),(2,3)], 'count': 5, 'expected': 1},
        # Test 2: Impossible (block disconnected in small grid)
        {'init': (2,0), 'targets': [(0,0),(1,0),(1,1),(0,3)], 'count': 4, 'expected': 0},
        # Test 3: Single addition possible
        {'init': (1,1), 'targets': [(1,2)], 'count': 1, 'expected': 1}
    ]
    passed = 0
    for case in test_cases:
        dut.init_r.value = case['init'][0]
        dut.init_c.value = case['init'][1]
        for i in range(4):
            if i < case['count']:
                dut.target_r[i].value = case['targets'][i][0]
                dut.target_c[i].value = case['targets'][i][1]
            else:
                dut.target_r[i].value = 0
                dut.target_c[i].value = 0
        dut.block_count.value = case['count']
        await Timer(1, units='ns')
        if dut.possible.value == case['expected']:
            passed += 1
        else:
            dut._log.error("Test failed: Expected %d got %d for case %s" % (case['expected'], dut.possible.value, str(case)))
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))