import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_verse_matcher(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (adapted for 4-line max)
    test_vectors = [
        # Input 1: Original sample (truncated to 4 lines)
        {
            'pattern': [2, 2, 3, 0],
            'text': [
                'intel    ',  # 9 chars - padding with spaces
                'code     ',
                'challenge',
                '         '  # Empty line
            ],
            'expected': 1  # YES
        },
        # Input 2: 4-line sample
        {
            'pattern': [1, 2, 3, 1],
            'text': [
                'a           ',
                'bcdefghi    ',
                'jklmnopq    ',
                'vwxyz       '
            ],
            'expected': 0  # NO (third line actual=2 vowels)
        },
        # Edge case: all zero
        {
            'pattern': [0, 0, 0, 0],
            'text': [
                'bcdfgh  ',
                'jklt    ',
                'mnpqrs  ',
                'xyz     '
            ],
            'expected': 1  # YES
        },
        # Early termination case
        {
            'pattern': [3, 3, 0, 0],
            'text': [
                'aaa       ',
                'abc       ',
                'xyz       ',
                '          '
            ],
            'expected': 0  # NO (second line actual=1)
        }
    ]
    
    passed = 0
    for test in test_vectors:
        # Setup inputs
        dut.start.value = 0
        for i in range(4):
            # Convert text lines to ASCII bytes
            line = test['text'][i].ljust(16)
            ascii_bytes = [ord(c) for c in line[:16]]
            for j in range(16):
                dut.text_lines[i][j].value = ascii_bytes[j]
            dut.pattern[i].value = test['pattern'][i]
        
        # Trigger start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 20 cycles)
        timeout = 0
        while not dut.done.value and timeout < 25:
            await RisingEdge(dut.clk)
            timeout += 1
        
        # Check result
        if timeout >=25:
            dut._log.error('Timeout waiting for done')
        else:
            result = int(dut.match.value)
            expected = test['expected']
            if result == expected:
                passed += 1
            else:
                dut._log.error(f'Test failed: expected={expected}, got={result}')
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f'{passed}/{len(test_vectors)} tests passed')
