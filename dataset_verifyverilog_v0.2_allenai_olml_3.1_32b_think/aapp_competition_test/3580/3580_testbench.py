import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock

# Helper to convert integer list to hex for verilog task
async def setup_dut(dut):
    # Define the hardcoded sequence 'a' from the prompt
    # 1, 2, 3, 1, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0
    seq_a = [1, 2, 3, 1, 2, 1, 1] + [0]*9
    
    # Initialize memory in DUT if accessible, otherwise we might need to pass via ports
    # Assuming the module uses external memory ports or hardcoded internal logic.
    # To make this verifiable, we will assume the module has a port for 'a' values
    # However, the prompt implies 'a' is hardcoded.
    # Let's assume the DUT has a mechanism to read 'a' or we pass it via inputs if specified.
    # Since the prompt says 'a' is hardcoded for simulation, I will create a custom task inside the testbench
    # to handle this if the DUT needs initialization, or just rely on the prompt's implicit requirement.
    
    # Wait for reset
    dut.start.value = 0
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    return seq_a

@cocotb.test()
async def test_longest_valid_prefix(dut):
    """Test longest valid prefix calculation"""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    seq_a = await setup_dut(dut)
    
    # Test Cases
    # 1. Query: Start=0, B=[1, 2, 3] -> Expected: 7 (sequence is 1,2,3,1,2,1,1)
    # 2. Query: Start=0, B=[1, 2] -> Expected: 2 (sequence 1,2, then 3 breaks)
    # 3. Query: Start=1, B=[2, 3] -> Expected: 2 (a[1]=2, a[2]=3, a[3]=1 breaks)
    # 4. Query: Start=2, B=[1, 2] -> Expected: 0 (a[2]=3 not in B)
    # 5. Query: Start=3, B=[1, 2] -> Expected: 4 (a[3]=1, a[4]=2, a[5]=1, a[6]=1)
    
    test_cases = [
        {"start": 0, "b": [1, 2, 3], "expected": 7},
        {"start": 0, "b": [1, 2], "expected": 2},
        {"start": 1, "b": [2, 3], "expected": 2},
        {"start": 2, "b": [1, 2], "expected": 0},
        {"start": 3, "b": [1, 2], "expected": 4},
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, tc in enumerate(test_cases):
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        # Drive inputs
        dut.start_index.value = tc["start"]
        dut.b_size.value = len(tc["b"])
        
        # Pad B array to 8 elements (width 8 bits each)
        for j in range(8):
            if j < len(tc["b"]):
                dut.b_data[j].value = tc["b"][j]
            else:
                dut.b_data[j].value = 0
                
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 30:
            await RisingEdge(dut.clk)
            timeout += 1
            
        if not dut.done.value:
            dut._log.error(f"Test {i+1}: Timeout waiting for done")
            continue
            
        # Check result
        actual = int(dut.result.value)
        if actual == tc["expected"]:
            dut._log.info(f"Test {i+1} PASSED: Start={tc['start']}, B={tc['b']}. Result {actual} == Expected {tc['expected']}")
            passed += 1
        else:
            dut._log.error(f"Test {i+1} FAILED: Start={tc['start']}, B={tc['b']}. Result {actual} != Expected {tc['expected']}")
            
    dut._log.info(f"Summary: {passed}/{total} tests passed")
    assert passed == total
