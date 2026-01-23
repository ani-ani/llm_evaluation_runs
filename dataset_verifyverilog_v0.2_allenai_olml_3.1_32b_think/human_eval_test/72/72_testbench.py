import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_will_it_fly(dut):
    # Initialize inputs
    dut.w.value = 0
    dut.q_len.value = 0
    for i in range(8):
        dut.q[i].value = 0
    
    await Timer(10, units='ns')
    
    # Test Case 1: [3, 2, 3], w=9 -> True (Balanced, Sum=8 <= 9)
    dut.q_len.value = 3
    dut.q[0].value = 3
    dut.q[1].value = 2
    dut.q[2].value = 3
    dut.w.value = 9
    await Timer(10, units='ns')
    assert dut.result.value == 1, "Test 1 Failed: [3,2,3], w=9"
    
    # Test Case 2: [1, 2], w=5 -> False (Unbalanced)
    dut.q_len.value = 2
    dut.q[0].value = 1
    dut.q[1].value = 2
    dut.w.value = 5
    await Timer(10, units='ns')
    assert dut.result.value == 0, "Test 2 Failed: [1,2], w=5"
    
    # Test Case 3: [3], w=5 -> True (Balanced, Sum=3 <= 5)
    dut.q_len.value = 1
    dut.q[0].value = 3
    dut.w.value = 5
    await Timer(10, units='ns')
    assert dut.result.value == 1, "Test 3 Failed: [3], w=5"
    
    # Test Case 4: [3, 2, 3], w=1 -> False (Balanced, but Sum=8 > 1)
    dut.q_len.value = 3
    dut.q[0].value = 3
    dut.q[1].value = 2
    dut.q[2].value = 3
    dut.w.value = 1
    await Timer(10, units='ns')
    assert dut.result.value == 0, "Test 4 Failed: [3,2,3], w=1"
    
    # Test Case 5: [1, 2, 3], w=6 -> False (Unbalanced, Sum=6 <= 6)
    dut.q_len.value = 3
    dut.q[0].value = 1
    dut.q[1].value = 2
    dut.q[2].value = 3
    dut.w.value = 6
    await Timer(10, units='ns')
    assert dut.result.value == 0, "Test 5 Failed: [1,2,3], w=6"
    
    # Test Case 6: [5], w=5 -> True (Balanced, Sum=5 <= 5)
    dut.q_len.value = 1
    dut.q[0].value = 5
    dut.w.value = 5
    await Timer(10, units='ns')
    assert dut.result.value == 1, "Test 6 Failed: [5], w=5"
    
    # Test Case 7: Empty list, w=0 -> True (Balanced, Sum=0 <= 0)
    dut.q_len.value = 0
    dut.w.value = 0
    await Timer(10, units='ns')
    assert dut.result.value == 1, "Test 7 Failed: [], w=0"
    
    # Test Case 8: [4, 4, 4], w=12 -> True (Balanced, Sum=12 <= 12)
    dut.q_len.value = 3
    dut.q[0].value = 4
    dut.q[1].value = 4
    dut.q[2].value = 4
    dut.w.value = 12
    await Timer(10, units='ns')
    assert dut.result.value == 1, "Test 8 Failed: [4,4,4], w=12"
