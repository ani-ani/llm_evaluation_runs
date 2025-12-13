import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
from itertools import chain

@cocotb.test()
async def test_tuple_grouper(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Test case 1: Original [('x', 'y'), ('x', 'z'), ('w', 't')] => 2 groups
    test1_in = [
        [ord('x'), ord('y'), 0],
        [ord('x'), ord('z'), 0],
        [ord('w'), ord('t'), 0],
        [0,0,0]
    ]
    test1_valid = [1,1,1,0]
    test1_expect = [
        [ord('x'), ord('y'), ord('z'), 0, 0, 0, 0],
        [ord('w'), ord('t'), 0, 0, 0, 0, 0],
        [0]*7,
        [0]*7
    ]

    # Test case 2: Original [('a','b'),('a','c'),('d','e')] => 2 groups
    test2_in = [
        [ord('a'), ord('b'), 0],
        [ord('a'), ord('c'), 0],
        [ord('d'), ord('e'), 0],
        [0,0,0]
    ]
    test2_valid = [1,1,1,0]
    test2_expect = [[ord('a'), ord('b'), ord('c')] + [0]*4,
                    [ord('d'), ord('e')] + [0]*5,
                    [0]*7,
                    [0]*7]

    # Test case 3: Original [('f','g'),('f','g'),('h','i')] => 2 groups
    test3_in = [
        [ord('f'), ord('g'), 0],
        [ord('f'), ord('g'), 0],
        [ord('h'), ord('i'), 0],
        [0,0,0]
    ]
    test3_valid = [1,1,1,0]
    test3_expect = [[ord('f'), ord('g'), ord('g')] + [0]*4,
                   [ord('h'), ord('i')] + [0]*5,
                   [0]*7,
                   [0]*7]

    all_tests = [
        (test1_in, test1_valid, test1_expect),
        (test2_in, test2_valid, test2_expect),
        (test3_in, test3_valid, test3_expect)
    ]

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    passed = 0
    for test_in, test_valid, expected in all_tests:
        # Flatten input
        for i in range(4):
            for j in range(3):  # 3 elements per tuple
                idx = i*3 + j
                dut.tuples.value[idx*8 +:8] = test_in[i][j]
        dut.valid_tuple.value = ( 
            (test_valid[0] << 0) |
            (test_valid[1] << 1) |
            (test_valid[2] << 2) |
            (test_valid[3] << 3))

        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait 4 cycles (max latency)
        for _ in range(4):
            await RisingEdge(dut.clk)

        # Verify output
        valid_groups = []
        for i in range(4):
            if dut.valid_group.value[i]:
                group = [dut.grouped.value[i*56 + j*8 +:8].integer for j in range(7)]
                valid_groups.append(group)
        
        # Compare with expected
        errors = []
        for i in range(4):
            actual_group = [dut.grouped.value[i*56 + j*8 +:8].integer for j in range(7)]
            expected_group = expected[i]
            valid = dut.valid_group.value[i]
            expected_valid = int(len(expected_group) > 0 and expected_group[0] != 0)
            
            valid_ok = valid == expected_valid
            content_ok = actual_group == expected_group
            
            if not (valid_ok and content_ok):
                errors.append(f"Group {i}: Got {actual_group} (valid={valid}) | Expected {expected_group} (valid={expected_valid})")
        
        if not errors:
            passed += 1
            dut._log.info(f"TEST PASSED")
        else:
            for err in errors:
                dut._log.error(err)
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(all_tests)} tests passed
")
