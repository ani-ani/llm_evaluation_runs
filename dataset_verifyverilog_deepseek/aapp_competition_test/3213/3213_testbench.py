import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_bat_spell(dut):
    # Step encoding: '+'=0, 'x'=1
    # Result encoding: keep=1, skip=0
    test_cases = [
        # (steps_str, S_val, expected_result)
        ("++xx+x++", 3, 0b11110011),  # Input1: should keep all except 5th
        ("xxxxxxxx", 3, 0b11000000),   # Input2: keep first two x's
        ("xx+x+x++xx", 1, 0b00000000)   # Input3: truncate to 8 bits, all skip
    ]
    
    # Convert test cases
    conv_cases = []
    for steps_str, S_val, expected in test_cases[:]:
        # Pad to 8 chars if needed
        steps_str = steps_str.ljust(8, 'x')[0:8]
        steps_bin = 0
        for i,c in enumerate(steps_str):
            steps_bin |= (1 if c=='x' else 0) << (7-i)
        conv_cases.append( (steps_bin, S_val, expected) )
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    for steps, S_val, expected in conv_cases:
        dut.steps.value = steps
        dut.S.value = S_val
        await RisingEdge(dut.clk)
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (16 cycles)
        for _ in range(20):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Verify result
        if dut.result.value == expected:
            passed += 1
        else:
            dut._log.error("Test failed: steps=%s S=%d expect=%08b got=%08b" % \\
                          (bin(steps), S_val, expected, dut.result.value))
    
    dut._log.info(f"{passed}/{len(conv_cases)} tests passed")
