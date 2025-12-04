import cocotb
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_filter(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    def encode_value(v_type, value):
        return (v_type << 8) | (value & 0xFF)
    
    test_cases = [
        {'input': [], 'expect': []},
        {'input': [('int',4), ('other',0), ('other',0), ('float',23), ('int',9), ('other',0)], 
         'expect': [4,9,0,0,0,0,0,0]},
        {'input': [('int',3),('other',0),('int',3),('int',3),('other',0),('other',0)], 
         'expect': [3,3,3,0,0,0,0,0]}
    ]
    
    passed = 0
    
    for case_idx, tc in enumerate(test_cases):
        # Apply reset
        dut.rst_n.value = 0
        dut.start.value = 0
        # Initialize inputs
        for i in range(8):
            if i < len(tc['input']):
                t, v = tc['input'][i]
                dut.values.value[i] = encode_value(1 if t=='int' else 2 if t=='float' else 3, v)
            else:
                dut.values.value[i] = encode_value(0, 0)
        
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check results
        expected = tc['expect'] + [0]*(8-len(tc['expect']))  # Pad to 8 elements
        valid_mask = sum(1 << i for i in range(8) if expected[i] != 0)
        
        match = True
        
        # Check valid mask
        if dut.valid_mask.value != valid_mask:
            dut._log.error(f"Case {case_idx}: Valid mask 0b{dut.valid_mask.value.binstr} != expected 0b{bin(valid_mask)}")
            match = False
        
        # Check filtered values
        for i in range(8):
            exp_val = expected[i]
            act_val = dut.result.value[i]
            if exp_val != 0 and act_val != exp_val:
                dut._log.error(f"Case {case_idx} pos{i}: Got {act_val} expected {exp_val}")
                match = False
        
        if match:
            passed += 1
            dut._log.info(f"Test {case_idx} PASSED")
        else:
            dut._log.error(f"Test {case_idx} FAILED")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")