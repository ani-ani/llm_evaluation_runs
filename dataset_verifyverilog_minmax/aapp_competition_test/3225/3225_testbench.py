import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_queue(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Scaled test cases (8 candidates max)
    test_cases = [
        (
            [3, 6, 2, 3, 2, 2, 2, 1],  # input
            2,                        # expected_rounds
            [6, 3, 2],                # expected_final (last step of sampe 1)
            3                          # queue_size
        ),
        (
            [17, 17, 17, 17, 0, 0, 0, 0],  
            0,
            [17, 17, 17, 17, 0, 0, 0, 0],
            8
        ),
        (
            [8, 1, 2, 3, 5, 6, 7, 0],   
            2,
            [8],
            1
        )
    ]
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    for i, (values, exp_rounds, exp_final, exp_size) in enumerate(test_cases):
        # Load test data
        for idx, val in enumerate(values):
            dut.initial_values[idx].value = val
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check results
        round_ok = dut.round_count.value == exp_rounds
        size_ok = dut.queue_size.value == exp_size
        final_ok = True
        
        # Check final queue values
        for q in range(8):
            if q < exp_size:
                if dut.final_queue[q].value != exp_final[q]:
                    final_ok = False
            else:
                if dut.final_queue[q].value != 0:  # padding with zeros
                    final_ok = False
        
        if round_ok and size_ok and final_ok:
            passed += 1
        else:
            dut._log.error("Test %d failed: Rounds=%d (exp %d), Size=%d (exp %d), Final=%s (exp %s)" % 
                          (i, dut.round_count.value, exp_rounds, dut.queue_size.value, exp_size, 
                           str([dut.final_queue[q].value for q in range(8)]), str(exp_final)))
        
        await RisingEdge(dut.clk)
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))