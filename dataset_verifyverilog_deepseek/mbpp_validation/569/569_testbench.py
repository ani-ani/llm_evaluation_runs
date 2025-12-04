import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

def str_to_bits(s):
    # Convert string to 4-byte packed format (max 4 chars)
    padded = s.ljust(4, '\\0')[:4]
    return sum(ord(c) << (8*i) for i,c in enumerate(padded))

def bits_to_str(bits):
    # Convert 32-bit value back to string
    s = ''
    for i in range(4):
        char = (bits >> (8*i)) & 0xff
        if char == 0: break
        s += chr(char)
    return s

@cocotb.test()
async def test_sorter(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Test cases (original adapted to max 4 elements)
    test_sublist = [
        ([['green', 'orange'], ['black', 'white']], [[['green','orange'],[]], [['black','white'],[]]]),
        ([['black'], ['green','orange'], ['white']], [[['black'],[]], [['green','orange'],[]], [['white'],[]]]),
        ([['a','b'], ['d','c'], ['g','h'], ['f','e']], [[['a','b'],[]], [['c','d'],[]], [['g','h'],[]], [['e','f'],[]]])
    ]
    
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    passed = 0
    total = 0
    
    for test, expects in test_sublist:_in, expected_out in test_cases:
        total += 1
        # Load sublist as 4-element array
        input_arr = [0]*4
        for idx, word in enumerate(sublist[:4]):  # Ensure max 4 elements
            input_arr[idx] = str_to_bits(word)
        
        # Apply inputs
        dut.sublist_in.value = input_arr
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for processing
        for _ in range(6):
            await RisingEdge(dut.clk)
        
        # Check done signal
        assert dut.done.value == 1, "Done signal not asserted after 6 cycles"
        
        # Read output
        out_data = [bits_to_str(int(dut.sorted_sublist.value[i])) for i in range(4)]
        
        # Compare with expected (only non-empty entries)
        expected_sorted = sorted([w for w in sublist if w != ''])  # Remove padding
        received_sorted = [w for w in out_data if w != '']        # Remove empty slots
        
        if received_sorted == expected_sorted:
            passed += 1
            dut._log.info(f"PASS: Input {sublist} -> Output {received_sorted}")
        else:
            dut._log.error(f"FAIL: Input {sublist} -> Got {received_sorted}, Expected {expected_sorted}")
    
    dut._log.info(f"{passed}/{total} tests passed")