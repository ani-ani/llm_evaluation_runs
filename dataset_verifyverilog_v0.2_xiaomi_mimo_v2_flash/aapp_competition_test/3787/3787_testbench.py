import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_permutation_generator(dut):
    """Test the permutation generator module."""
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    dut.A.value = 0
    dut.B.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: N=5, A=3, B=2
    # Expected Output: 5 4 1 2 3 (or similar valid sequence)
    # Standard construction: Large decreasing block, small increasing block
    dut.N.value = 5
    dut.A.value = 3
    dut.B.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    result = []
    cycles = 0
    max_cycles = 20 # Safety limit
    while cycles < max_cycles:
        if dut.valid_out.value == 1:
            result.append(int(dut.data_out.value))
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
        cycles += 1
    
    dut._log.info(f"Test 1 Result: {result}")
    
    # Verification
    # Check length
    if len(result) != 5:
        raise TestFailure(f"Expected length 5, got {len(result)}")
    
    # Check permutation (unique numbers 1..5)
    if sorted(result) != [1, 2, 3, 4, 5]:
        raise TestFailure(f"Not a valid permutation of 1..5: {result}")
        
    # Check LIS = 3 and LDS = 2
    # LIS
    lis = [1]*5
    for i in range(5):
        for j in range(i):
            if result[j] < result[i]:
                lis[i] = max(lis[i], lis[j] + 1)
    max_lis = max(lis)
    
    # LDS
    lds = [1]*5
    for i in range(5):
        for j in range(i):
            if result[j] > result[i]:
                lds[i] = max(lds[i], lds[j] + 1)
    max_lds = max(lds)
    
    dut._log.info(f"Calculated LIS: {max_lis}, LDS: {max_lds}")
    
    if max_lis != 3:
        raise TestFailure(f"LIS check failed: expected 3, got {max_lis}")
    if max_lds != 2:
        raise TestFailure(f"LDS check failed: expected 2, got {max_lds}")

    # Test Case 2: N=1, A=1, B=1
    # Expected: 1
    await RisingEdge(dut.clk)
    dut.N.value = 1
    dut.A.value = 1
    dut.B.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    result = []
    cycles = 0
    while cycles < max_cycles:
        if dut.valid_out.value == 1:
            result.append(int(dut.data_out.value))
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
        cycles += 1
        
    dut._log.info(f"Test 2 Result: {result}")
    if result != [1]:
        raise TestFailure(f"Test 2 failed: expected [1], got {result}")

    # Test Case 3: N=4, A=2, B=2
    # rem=2, base=2. Group 0 (size 2): 4, 3. Group 1 (size 2): 1, 2.
    # Result: 4, 3, 1, 2
    await RisingEdge(dut.clk)
    dut.N.value = 4
    dut.A.value = 2
    dut.B.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    result = []
    cycles = 0
    while cycles < max_cycles:
        if dut.valid_out.value == 1:
            result.append(int(dut.data_out.value))
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
        cycles += 1

    dut._log.info(f"Test 3 Result: {result}")
    if sorted(result) != [1, 2, 3, 4]:
        raise TestFailure(f"Test 3 failed: invalid permutation {result}")
    
    # Verify LIS=2, LDS=2
    lis = [1]*4
    for i in range(4):
        for j in range(i):
            if result[j] < result[i]:
                lis[i] = max(lis[i], lis[j] + 1)
    max_lis = max(lis)
    
    lds = [1]*4
    for i in range(4):
        for j in range(i):
            if result[j] > result[i]:
                lds[i] = max(lds[i], lds[j] + 1)
    max_lds = max(lds)
    
    if max_lis != 2 or max_lds != 2:
        raise TestFailure(f"Test 3 constraints failed: LIS={max_lis}, LDS={max_lds}")

    # Test Case 4: N=6, A=4, B=2
    # rem=2, base=2. Group 0 (size 2): 6, 5. Group 1 (size 4): 1, 2, 3, 4.
    # Result: 6, 5, 1, 2, 3, 4
    await RisingEdge(dut.clk)
    dut.N.value = 6
    dut.A.value = 4
    dut.B.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    result = []
    cycles = 0
    while cycles < max_cycles:
        if dut.valid_out.value == 1:
            result.append(int(dut.data_out.value))
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
        cycles += 1

    dut._log.info(f"Test 4 Result: {result}")
    if sorted(result) != [1, 2, 3, 4, 5, 6]:
        raise TestFailure(f"Test 4 failed: invalid permutation {result}")
    
    # Verify LIS=4, LDS=2
    lis = [1]*6
    for i in range(6):
        for j in range(i):
            if result[j] < result[i]:
                lis[i] = max(lis[i], lis[j] + 1)
    max_lis = max(lis)
    
    lds = [1]*6
    for i in range(6):
        for j in range(i):
            if result[j] > result[i]:
                lds[i] = max(lds[i], lds[j] + 1)
    max_lds = max(lds)
    
    if max_lis != 4 or max_lds != 2:
        raise TestFailure(f"Test 4 constraints failed: LIS={max_lis}, LDS={max_lds}")

    print("All tests passed!")