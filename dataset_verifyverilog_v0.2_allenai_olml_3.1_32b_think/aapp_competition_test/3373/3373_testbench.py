import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

async def evaluate_parentheses(pieces):
    """Evaluate maximum balanced length in Python for verification"""
    # Parse pieces to (min_prefix, final_balance, length)
    parsed = []
    for p in pieces:
        if not p:
            continue
        balance = 0
        min_bal = 0
        for c in p:
            if c == '(':
                balance += 1
            else:
                balance -= 1
            min_bal = min(min_bal, balance)
        parsed.append({
            'min_prefix': -min_bal,  # how many '(' needed before
            'final_balance': balance,
            'length': len(p)
        })
    
    n = len(parsed)
    max_len = 0
    
    # Try all subsets
    for mask in range(1 << n):
        current_balance = 0
        total_len = 0
        valid = True
        for i in range(n):
            if mask & (1 << i):
                piece = parsed[i]
                if current_balance < piece['min_prefix']:
                    valid = False
                    break
                current_balance += piece['final_balance']
                total_len += piece['length']
        if valid and current_balance == 0:
            max_len = max(max_len, total_len)
    
    return max_len

@cocotb.test()
async def test_balanced_parentheses(dut):
    """Test the balanced parentheses solver module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_pieces.value = 0
    for i in range(8):
        dut.pieces[i].value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test case 1: 3 pieces
    pieces1 = ['())', '((()', ')()']
    dut.num_pieces.value = 3
    dut.pieces[0].value = 0x1A00000000000000  # ()) -> 01 10 10
    dut.pieces[1].value = 0x1111A00000000000  # ((() -> 01 01 01 10
    dut.pieces[2].value = 0x1A10000000000000  # )() -> 10 01 10
    # Note: Encoding: each char = 2 bits, MSB first
    # Let's use proper encoding: char i at bits (2*i+1:2*i)
    # For simplicity, we'll manually encode:
    # ()): 01,10,10 = 0x1A in lowest 6 bits
    # But let's be explicit:
    def encode_paren(s):
        result = 0
        for i, c in enumerate(s):
            if c == '(':
                val = 1
            else:
                val = 2
            result |= (val << (2*i))
        return result
    
    dut.pieces[0].value = encode_paren('())')
    dut.pieces[1].value = encode_paren('((()')
    dut.pieces[2].value = encode_paren(')()')
    
    await Timer(10, units='ns')
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Timeout waiting for done signal")
    
    result1 = int(dut.max_length.value)
    expected1 = evaluate_parentheses(pieces1)
    
    print(f"Test 1: Expected {expected1}, Got {result1}")
    if result1 != expected1:
        raise TestFailure(f"Test 1 failed: expected {expected1}, got {result1}")
    
    await Timer(100, units='ns')
    
    # Test case 2: 5 pieces (simple)
    pieces2 = [')))))', ')', '(', '((', '))((']
    dut.num_pieces.value = 5
    dut.pieces[0].value = encode_paren(')))))')
    dut.pieces[1].value = encode_paren(')')
    dut.pieces[2].value = encode_paren('(')
    dut.pieces[3].value = encode_paren('((')
    dut.pieces[4].value = encode_paren('))((')
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    result2 = int(dut.max_length.value)
    expected2 = evaluate_parentheses(pieces2)
    
    print(f"Test 2: Expected {expected2}, Got {result2}")
    if result2 != expected2:
        raise TestFailure(f"Test 2 failed: expected {expected2}, got {result2}")
    
    # Test case 3: Empty/edge cases
    pieces3 = ['(', ')', '((']
    dut.num_pieces.value = 3
    dut.pieces[0].value = encode_paren('(')
    dut.pieces[1].value = encode_paren(')')
    dut.pieces[2].value = encode_paren('((')
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    result3 = int(dut.max_length.value)
    expected3 = evaluate_parentheses(pieces3)
    
    print(f"Test 3: Expected {expected3}, Got {result3}")
    if result3 != expected3:
        raise TestFailure(f"Test 3 failed: expected {expected3}, got {result3}")
    
    print("All tests passed!")
