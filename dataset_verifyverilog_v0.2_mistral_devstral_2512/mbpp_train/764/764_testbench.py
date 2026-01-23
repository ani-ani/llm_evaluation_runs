import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_digit_counter(dut):
    # Create a clock with a 10ns period
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Dictionary mapping ASCII characters to their integer values
    ascii_map = {'0': 0x30, '1': 0x31, '2': 0x32, '3': 0x33, '4': 0x34, 
                 '5': 0x35, '6': 0x36, '7': 0x37, '8': 0x38, '9': 0x39}
    
    # Test cases: (Input String, Expected Digit Count)
    # Input strings are padded to 16 characters with spaces or other chars if needed
    test_cases = [
        ('program2bedone', 1),
        ('3wonders      ', 1),       # Padded to 16
        ('123           ', 3),       # Padded to 16
        ('3wond-1ers2   ', 3)        # Padded to 16
    ]

    for input_str, expected_count in test_cases:
        # Pad the string to exactly 16 characters
        padded_input = input_str.ljust(16)
        
        # Memory storage for the test (simulating external memory)
        # In the testbench, we store the ASCII values to be returned when dut.addr_out changes
        memory = [ord(c) for c in padded_input]
        
        dut.rst_n.value = 0
        dut.start.value = 0
        await Timer(20, units='ns')
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Start the process
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        done = False
        # Monitor loop to drive char_in based on dut.addr_out
        while not done:
            # Check current state to drive inputs properly if needed
            # But here we just need to feed char_in based on address
            # Since the module reads sequentially, we can just drive the data
            # We assume the module holds the address for one cycle to read data
            
            await RisingEdge(dut.clk)
            
            # The testbench drives char_in based on the address output by DUT
            # Check if address is valid (0 to 15)
            if dut.addr_out.value.is_resolvable:
                addr = int(dut.addr_out.value)
                if 0 <= addr < 16:
                    dut.char_in.value = memory[addr]
            
            # Check if done
            if dut.done.value == 1:
                done = True
                # Check result
                actual_count = int(dut.count.value)
                print(f"Test: '{input_str}' -> Expected: {expected_count}, Got: {actual_count}")
                assert actual_count == expected_count, f"Mismatch!"
                
        await RisingEdge(dut.clk)
    
    print(f"All tests passed.")