import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_unique_digits(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_cases = [
        {'input': [15, 33, 1422, 1], 'expected': [1, 15, 33]},
        {'input': [152, 323, 1422, 10], 'expected': []},
        {'input': [12345, 2033, 111, 151], 'expected': [111, 151]},
        {'input': [135, 103, 31, 0], 'expected': [31, 135]}
    ]
    
    passed = 0
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for case in test_cases:
        # Pad inputs to 4 elements
        inp = case['input'] + [0] * (4 - len(case['input']))
        dut.numbers.value = inp
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for processing (10 cycles)
        for _ in range(12):
            await RisingEdge(dut.clk)
        
        # Read outputs
        outputs = []
        for i in range(4):
            if dut.valid_mask.value & (1 << i):
                outputs.append(int(dut.sorted_out[i].value))
        
        expected_padded = case['expected'] + [0] * (4 - len(case['expected']))
        
        if outputs == case['expected']:
            passed += 1
            dut._log.info(f"PASS: Input {inp} → Output {outputs}")
        else:
            dut._log.error(f"FAIL: Input {inp} Got {outputs}, Expected {case['expected']}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")