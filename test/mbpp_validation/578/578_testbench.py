import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_interleaver(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (scaled to 8 elements max)
    test_cases = [
        {
            "lists": ([1,2,3,4,5,6,7], [10,20,30,40,50,60,70], [100,200,300,400,500,600,700]),
            "expected": [1,10,100,2,20,200,3,30,300,4,40,400,5,50,500,6,60,600,7,70,700]
        },
        {
            "lists": ([10,20], [15,2], [5,10]),
            "expected": [10,15,5,20,2,10]
        },
        {
            "lists": ([11,44], [10,15], [20,5]),
            "expected": [11,10,20,44,15,5]
        },
        {
            "lists": ([], [], []),  # Edge case: empty lists
            "expected": []
        }
    ]
    
    passed = 0
    total = len(test_cases)
    
    for tc in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        list1, list2, list3 = tc["lists"]
        n = len(list1)
        
        for i in range(8):
            dut.list1[i].value = list1[i] if i < n else 0
            dut.list2[i].value = list2[i] if i < n else 0
            dut.list3[i].value = list3[i] if i < n else 0
        
        dut.list_len.value = n
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect outputs
        outputs = []
        timeout = 3*n + 10  # Allow extra cycles
        
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.valid.value:
                outputs.append(int(dut.data_out.value))
            if dut.done.value:
                break
        
        # Verify
        if outputs == tc["expected"]:
            passed += 1
            dut._log.info(f"PASS: {tc['lists']} => {outputs}")
        else:
            dut._log.error(f"FAIL: {tc['lists']}
  Expected: {tc['expected']}
  Received: {outputs}")
    
    dut._log.info(f"RESULT: {passed}/{total} tests passed")