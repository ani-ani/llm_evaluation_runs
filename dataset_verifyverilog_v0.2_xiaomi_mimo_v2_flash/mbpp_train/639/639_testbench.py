import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_name_filter_sum(dut):
    """Test name_filter_sum module with various test cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize inputs
    dut.rst_n.value = 1
    dut.start.value = 0
    dut.valid_char.value = 0
    dut.char_data.value = 0
    
    # Reset
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case definitions
    test_cases = [
        {
            'name': 'Test 1: Mixed valid/invalid names',
            'names': [
                # 'sally' -> 'sally\x00\x00' (invalid: starts with lowercase)
                [ord('s'), ord('a'), ord('l'), ord('l'), ord('y'), 0, 0, 0],
                # 'Dylan' -> 'Dylan\x00\x00' (valid: D uppercase, ylan lowercase)
                [ord('D'), ord('y'), ord('l'), ord('a'), ord('n'), 0, 0, 0],
                # 'rebecca' -> 'rebecca' (invalid: starts with lowercase)
                [ord('r'), ord('e'), ord('b'), ord('e'), ord('c'), ord('c'), ord('a'), 0],
                # 'Diana' -> 'Diana\x00\x00' (valid)
                [ord('D'), ord('i'), ord('a'), ord('n'), ord('a'), 0, 0, 0],
                # 'Joanne' -> 'Joanne\x00' (valid)
                [ord('J'), ord('o'), ord('a'), ord('n'), ord('n'), ord('e'), 0, 0],
                # 'keith' -> 'keith\x00\x00' (invalid)
                [ord('k'), ord('e'), ord('i'), ord('t'), ord('h'), 0, 0, 0],
                [0]*8, [0]*8  # Empty names
            ],
            'expected': 16  # Dylan(5) + Diana(5) + Joanne(6) = 16
        },
        {
            'name': 'Test 2: PHP, res, Python, abcd, Java, aaa',
            'names': [
                # 'php' -> 'php\x00\x00\x00\x00\x00' (invalid: all lowercase)
                [ord('p'), ord('h'), ord('p'), 0, 0, 0, 0, 0],
                # 'res' -> 'res\x00\x00\x00\x00\x00' (invalid)
                [ord('r'), ord('e'), ord('s'), 0, 0, 0, 0, 0],
                # 'Python' -> 'Python\x00' (valid)
                [ord('P'), ord('y'), ord('t'), ord('h'), ord('o'), ord('n'), 0, 0],
                # 'abcd' -> 'abcd\x00\x00\x00\x00' (invalid)
                [ord('a'), ord('b'), ord('c'), ord('d'), 0, 0, 0, 0],
                # 'Java' -> 'Java\x00\x00\x00\x00' (valid)
                [ord('J'), ord('a'), ord('v'), ord('a'), 0, 0, 0, 0],
                # 'aaa' -> 'aaa\x00\x00\x00\x00\x00' (invalid)
                [ord('a'), ord('a'), ord('a'), 0, 0, 0, 0, 0],
                [0]*8, [0]*8
            ],
            'expected': 10  # Python(6) + Java(4) = 10
        },
        {
            'name': 'Test 3: abcd, Python, abba, aba',
            'names': [
                # 'abcd' -> 'abcd\x00\x00\x00\x00' (invalid)
                [ord('a'), ord('b'), ord('c'), ord('d'), 0, 0, 0, 0],
                # 'Python' -> 'Python\x00' (valid)
                [ord('P'), ord('y'), ord('t'), ord('h'), ord('o'), ord('n'), 0, 0],
                # 'abba' -> 'abba\x00\x00\x00\x00' (invalid)
                [ord('a'), ord('b'), ord('b'), ord('a'), 0, 0, 0, 0],
                # 'aba' -> 'aba\x00\x00\x00\x00\x00' (invalid)
                [ord('a'), ord('b'), ord('a'), 0, 0, 0, 0, 0],
                [0]*8, [0]*8, [0]*8, [0]*8
            ],
            'expected': 6  # Python(6)
        },
        {
            'name': 'Test 4: All invalid names',
            'names': [
                [ord('a'), ord('b'), 0, 0, 0, 0, 0, 0],
                [ord('x'), ord('y'), ord('z'), 0, 0, 0, 0, 0],
                [ord('1'), ord('2'), 0, 0, 0, 0, 0, 0],
                [0]*8, [0]*8, [0]*8, [0]*8, [0]*8
            ],
            'expected': 0
        },
        {
            'name': 'Test 5: All valid names',
            'names': [
                # 'A' -> valid
                [ord('A'), 0, 0, 0, 0, 0, 0, 0],
                # 'Bb' -> valid
                [ord('B'), ord('b'), 0, 0, 0, 0, 0, 0],
                # 'Ccd' -> valid
                [ord('C'), ord('c'), ord('d'), 0, 0, 0, 0, 0],
                # 'Defg' -> valid
                [ord('D'), ord('e'), ord('f'), ord('g'), 0, 0, 0, 0],
                [0]*8, [0]*8, [0]*8, [0]*8
            ],
            'expected': 10  # 1+2+3+4 = 10
        }
    ]
    
    for test_idx, test_case in enumerate(test_cases):
        print(f"
Running {test_case['name']}")
        
        # Store test data for simulation
        names = test_case['names']
        expected = test_case['expected']
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for computation to start
        await RisingEdge(dut.clk)
        
        # Feed characters to the DUT
        current_name_idx = 0
        current_char_idx = 0
        feed_complete = False
        
        while not feed_complete:
            # Check if DUT is requesting data
            if current_name_idx < 8:
                # Provide character if requested
                if current_char_idx < 8:
                    dut.char_data.value = names[current_name_idx][current_char_idx]
                    dut.valid_char.value = 1
                    await RisingEdge(dut.clk)
                    dut.valid_char.value = 0
                    current_char_idx += 1
                    if current_char_idx >= 8:
                        current_char_idx = 0
                        current_name_idx += 1
                else:
                    await RisingEdge(dut.clk)
            else:
                feed_complete = True
            
            # Check if done
            if dut.done.value == 1:
                break
            
            # Safety timeout
            for _ in range(200):
                await RisingEdge(dut.clk)
                if dut.done.value == 1:
                    break
        
        # Read result
        actual = int(dut.result.value)
        
        print(f"Expected: {expected}, Got: {actual}")
        
        if actual != expected:
            raise TestFailure(f"Test {test_idx+1} failed: expected {expected}, got {actual}")
    
    print(f"
All tests passed! 5/5 tests completed successfully")
