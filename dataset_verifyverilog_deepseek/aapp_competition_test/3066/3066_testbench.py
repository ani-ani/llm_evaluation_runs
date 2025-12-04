import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_tape_art(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    test_cases = [
        # Valid case (Sample 1 scaled)
        {'n':6, 'c':[1,2,3,3,2,1]+[0]*10, 'exp_count':3, 'exp_instructions':[[1,6,1],[2,5,2],[3,4,3]], 'imp':0},
        # Invalid case (Sample 2)
        {'n':4, 'c':[1,2,1,2]+[0]*12, 'exp_count':0, 'exp_instructions':[], 'imp':1},
        # Additional test case (partial coverage)
        {'n':3, 'c':[5,5,5]+[0]*13, 'exp_count':1, 'exp_instructions':[[1,3,5]], 'imp':0}
    ]
    
    passed = 0
    for case in test_cases:
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.n.value = case['n']
        for i in range(16):
            if i < case['n']:
                dut.c[i].value = case['c'][i]
            else:
                dut.c[i].value = 0  # pad unused
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify outputs
        if case['imp']:
            if dut.impossible.value != 1:
                dut._log.error(f"Test failed: Should be impossible but got valid output")
            else:
                passed += 1
        else:
            if dut.impossible.value == 1:
                dut._log.error(f"Test failed: Valid case marked impossible")
            elif dut.instr_count.value != case['exp_count']:
                dut._log.error(f"Count mismatch: {dut.instr_count.value} vs {case['exp_count']}")
            else:
                valid = True
                for i in range(case['exp_count']):
                    l = dut.instr_l[i].value
                    r = dut.instr_r[i].value
                    c = dut.instr_c[i].value
                    if l != case['exp_instructions'][i][0] or r != case['exp_instructions'][i][1] or c != case['exp_instructions'][i][2]:
                        dut._log.error(f"Instruction {i} mismatch: L={l}/{case['exp_instructions'][i][0]}, R={r}/{case['exp_instructions'][i][1]}, C={c}/{case['exp_instructions'][i][2]}")
                        valid = False
                if valid:
                    passed += 1
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")