import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_harvard(dut):
    # Test cases (b,s, program, expected)
    test_cases = [
        (1, 2, "V1 V2 V1 V1 V2", 5),
        (2, 1, "V1 V2 V1 V1 V2", 6),
        (1, 2, "R3 V1 V2 V1", 9) // Original R10 case scaled
    ]

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    passed = 0
    for (b_val, s_val, program_str, expected) in test_cases:
        # Encode program into 16x6-bit tokens
        tokens = []
        for elem in program_str.split():
            if elem[0] == 'V':
                val = int(elem[1:])
                tokens.append((0 <<4) | (val & 0xF))
            elif elem[0] == 'R':
                val = int(elem[1:])
                tokens.append((1 <<4) | (val & 0xF))
            else: # 'E'
                tokens.append((2 <<4))
        # Pad to 16 tokens
        while len(tokens) < 16:
            tokens.append(0)
        packed_program = sum(( (tok << (6*i)) for i, tok in enumerate(tokens) ))
        
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        dut.b.value = b_val
        dut.s.value = s_val
        dut.program.value = packed_program
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await ClockCycles(dut.clk, 300)
        
        if int(dut.min_instructions.value) == expected:
            passed +=1
        else:
            dut._log.error(f"Test failed: ({b_val},{s_val},'{program_str}') => {dut.min_instructions.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)