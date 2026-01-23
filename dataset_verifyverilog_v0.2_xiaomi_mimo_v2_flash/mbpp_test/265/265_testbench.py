import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_list_splitter_basic(dut):
    """Test basic list splitting with step=3"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    dut.data_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: [1,2,3,4,5,6,7,8,9,10,11,12,13,14] with step=3
    # Expected: buffer0=[1,4,7,10,13], buffer1=[2,5,8,11,14], buffer2=[3,6,9,12]
    test_data = [1,2,3,4,5,6,7,8,9,10,11,12,13,14]
    step = 3
    num_elements = 14
    
    # Start computation
    dut.start.value = 1
    dut.step.value = step
    dut.num_elements.value = num_elements
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Collect outputs
    outputs = {0: [], 1: [], 2: []}
    
    for i, val in enumerate(test_data):
        dut.data_in.value = val
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
        
        if dut.write_enable.value:
            buf_id = int(dut.buffer_id.value)
            buf_idx = int(dut.buffer_index.value)
            data = int(dut.data_out.value)
            if buf_id < 3:  # Only track buffers 0-2 for step=3
                # Ensure correct ordering in each buffer
                outputs[buf_id].append(data)
        
        dut.data_valid.value = 0
        await RisingEdge(dut.clk)
    
    # Wait for done
    timeout = 20
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Done signal not asserted within timeout")
    
    # Verify results
    expected = {0: [1,4,7,10,13], 1: [2,5,8,11,14], 2: [3,6,9,12]}
    
    for buf_id in range(3):
        if outputs[buf_id] != expected[buf_id]:
            raise TestFailure(f"Buffer {buf_id}: expected {expected[buf_id]}, got {outputs[buf_id]}")
    
    print(f"Test 1 passed: {outputs}")

@cocotb.test()
async def test_list_splitter_step2(dut):
    """Test list splitting with step=2"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 3: ['python','java','C','C++','DBMS','SQL'] with step=2
    # Represent strings as bytes: python->80, java->74, C->67, C++->68, DBMS->69, SQL->83
    # Actually, let's use numbers for simplicity: [100, 200, 3, 4, 5, 6] representing the strings
    # Expected: buffer0=[100,3,5], buffer1=[200,4,6]
    test_data = [100, 200, 3, 4, 5, 6]
    step = 2
    num_elements = 6
    
    dut.start.value = 1
    dut.step.value = step
    dut.num_elements.value = num_elements
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    outputs = {0: [], 1: []}
    
    for val in test_data:
        dut.data_in.value = val
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
        
        if dut.write_enable.value:
            buf_id = int(dut.buffer_id.value)
            data = int(dut.data_out.value)
            if buf_id < 2:
                outputs[buf_id].append(data)
        
        dut.data_valid.value = 0
        await RisingEdge(dut.clk)
    
    timeout = 20
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Done signal not asserted")
    
    expected = {0: [100,3,5], 1: [200,4,6]}
    
    for buf_id in range(2):
        if outputs[buf_id] != expected[buf_id]:
            raise TestFailure(f"Buffer {buf_id}: expected {expected[buf_id]}, got {outputs[buf_id]}")
    
    print(f"Test 2 passed: {outputs}")

@cocotb.test()
async def test_list_splitter_full(dut):
    """Test with maximum elements and step=4"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 16 elements, step=4
    # Expected: buffer0=[0,4,8,12], buffer1=[1,5,9,13], buffer2=[2,6,10,14], buffer3=[3,7,11,15]
    test_data = list(range(16))
    step = 4
    num_elements = 16
    
    dut.start.value = 1
    dut.step.value = step
    dut.num_elements.value = num_elements
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    outputs = {0: [], 1: [], 2: [], 3: []}
    
    for val in test_data:
        dut.data_in.value = val
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
        
        if dut.write_enable.value:
            buf_id = int(dut.buffer_id.value)
            buf_idx = int(dut.buffer_index.value)
            data = int(dut.data_out.value)
            if buf_id < 4:
                outputs[buf_id].append(data)
        
        dut.data_valid.value = 0
        await RisingEdge(dut.clk)
    
    timeout = 25
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Done signal not asserted")
    
    expected = {0: [0,4,8,12], 1: [1,5,9,13], 2: [2,6,10,14], 3: [3,7,11,15]}
    
    for buf_id in range(4):
        if outputs[buf_id] != expected[buf_id]:
            raise TestFailure(f"Buffer {buf_id}: expected {expected[buf_id]}, got {outputs[buf_id]}")
    
    print(f"Test 3 passed: {outputs}")

@cocotb.test()
async def test_list_splitter_single(dut):
    """Test with step=1 (no splitting)"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_data = [5, 10, 15, 20]
    step = 1
    num_elements = 4
    
    dut.start.value = 1
    dut.step.value = step
    dut.num_elements.value = num_elements
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    outputs = {0: []}
    
    for val in test_data:
        dut.data_in.value = val
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
        
        if dut.write_enable.value:
            buf_id = int(dut.buffer_id.value)
            data = int(dut.data_out.value)
            if buf_id == 0:
                outputs[0].append(data)
        
        dut.data_valid.value = 0
        await RisingEdge(dut.clk)
    
    timeout = 10
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Done signal not asserted")
    
    expected = {0: [5,10,15,20]}
    
    if outputs[0] != expected[0]:
        raise TestFailure(f"Buffer 0: expected {expected[0]}, got {outputs[0]}")
    
    print(f"Test 4 passed: {outputs}")

@cocotb.test()
async def test_list_splitter_edge(dut):
    """Test with minimum elements (1 element)"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_valid.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_data = [42]
    step = 3
    num_elements = 1
    
    dut.start.value = 1
    dut.step.value = step
    dut.num_elements.value = num_elements
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    outputs = {0: [], 1: [], 2: []}
    
    for val in test_data:
        dut.data_in.value = val
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
        
        if dut.write_enable.value:
            buf_id = int(dut.buffer_id.value)
            data = int(dut.data_out.value)
            if buf_id < 3:
                outputs[buf_id].append(data)
        
        dut.data_valid.value = 0
        await RisingEdge(dut.clk)
    
    timeout = 10
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Done signal not asserted")
    
    # Element 0 goes to buffer 0
    if outputs[0] != [42]:
        raise TestFailure(f"Buffer 0: expected [42], got {outputs[0]}")
    
    print(f"Test 5 passed: {outputs}")

print("All tests completed!")