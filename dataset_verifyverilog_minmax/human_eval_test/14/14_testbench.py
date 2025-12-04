import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_prefixer(dut):
    # Define test cases (input_str, len, expected_prefixes)
    test_cases = [
        ('',        0, []),
        ('asdfgh',  6, ['a', 'as', 'asd', 'asdf', 'asdfg', 'asdfgh']),
        ('WWW',     3, ['W',   'WW',   'WWW'])
    ]
    
    # Convert strings to packed bytes
    def str_to_bin(s):
        packed = 0
        for i, c in enumerate(s[:8]):
            packed |= ord(c) << (56 - 8*i)
        return packed
    
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    passed = 0
    for s, length, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Skip empty string test for zero-length handling
        if length == 0:
            dut.start.value = 1
            dut.str.value = str_to_bin(s)
            dut.len.value = length
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await RisingEdge(dut.clk)
            assert dut.done.value == 1, f"Empty string should set done immediately"
            passed += 1
            continue
        
        # Start processing
        dut.str.value = str_to_bin(s)
        dut.len.value = length
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Check prefixes
        prefix_count = 0
        failure = False
        
        for cycle in range(length+1):
            await RisingEdge(dut.clk)
            
            if cycle == 0:
                # Skip dummy cycle after start
                continue
            
            current_length = cycle
            
            # Extract current prefix
            expected_prefix = expected[prefix_count]
            captured = ""
            for i in range(current_length):
                byte_val = (dut.prefix.value >> (56 - 8*i)) & 0xFF
                captured += chr(byte_val)
            
            # Verify output
            if not (dut.ready.value == 1 and captured == expected_prefix):
                dut._log.error(f"FAIL '{s}': Got '{captured}' (len {dut.plen.value}) "
                            f"expected '{expected_prefix}'")
                failure = True
                break
            
            prefix_count += 1
            # Check done signal on last prefix
            if cycle == length:
                if dut.done.value != 1:
                    dut._log.error(f"FAIL '{s}': Done not asserted on last prefix")
                    failure = True
            else:
                if dut.done.value != 0:
                    dut._log.error(f"FAIL '{s}': Done asserted prematurely")
                    failure = True
        
        if not failure:
            passed += 1
            dut._log.info(f"PASS '{s}'")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")