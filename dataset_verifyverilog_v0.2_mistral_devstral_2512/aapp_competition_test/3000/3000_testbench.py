import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

# Modulus for calculations
MOD = 1000000007

def evaluate_bracket_sequence(tokens):
    """Python reference implementation for bracket sequence evaluation."""
    stack = []
    current_value = 0
    current_mode = 0  # 0 = add, 1 = multiply
    depth = 0
    
    for token in tokens:
        if isinstance(token, int):
            if current_mode == 0:
                current_value = (current_value + token) % MOD
            else:
                current_value = (current_value * token) % MOD
        elif token == '(':
            # Push current state
            stack.append((current_value, current_mode, depth))
            depth += 1
            current_value = 0
            current_mode = depth % 2
        elif token == ')':
            temp = current_value
            if stack:
                current_value, current_mode, depth = stack.pop()
                if current_mode == 0:
                    current_value = (current_value + temp) % MOD
                else:
                    current_value = (current_value * temp) % MOD
    
    return current_value

def tokenize_and_encode(input_str):
    """Convert input string to token list and encode for Verilog."""
    tokens = []
    encoded = []
    parts = input_str.strip().split()
    
    for part in parts:
        if part == '(':
            tokens.append('(')
            encoded.append(0x28)  # '(' character
        elif part == ')':
            tokens.append(')')
            encoded.append(0x29)  # ')' character
        else:
            val = int(part)
            tokens.append(val)
            encoded.append(val)
    
    return tokens, encoded

@cocotb.test()
async def test_bracket_eval(dut):
    """Test bracket sequence evaluation module."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.token_in.value = 0
    dut.token_valid.value = 0
    dut.token_end.value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ([2, 3], "2 3"),
        (['(', 2, '(', 2, 1, ')', ')', 3], "( 2 ( 2 1 ) ) 3"),
        (['(', 12, 3, ')'], "( 12 3 )"),
        (['(', 2, ')', '(', 3, ')'], "( 2 ) ( 3 )"),
        (['(', '(', 2, 3, ')', ')'], "( ( 2 3 ) )"),
        ([1, '(', 0, '(', 583920, '(', 2839, 82, ')', ')', ')'], "1 ( 0 ( 583920 ( 2839 82 ) ) )")
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (tokens, description) in enumerate(test_cases):
        print(f"
Test {i+1}: {description}")
        
        # Calculate expected value
        expected = evaluate_bracket_sequence(tokens)
        print(f"Expected: {expected}")
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed tokens
        for idx, token in enumerate(tokens):
            if isinstance(token, int):
                dut.token_in.value = token % 256  # Limit to 8 bits for scaled version
            else:
                if token == '(':
                    dut.token_in.value = 0x28
                else:
                    dut.token_in.value = 0x29
            
            dut.token_valid.value = 1
            dut.token_end.value = 1 if idx == len(tokens) - 1 else 0
            await RisingEdge(dut.clk)
            dut.token_valid.value = 0
            dut.token_end.value = 0
        
        # Wait for done
        timeout = 50
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.done.value != 1:
            print(f"FAILED: Done signal not asserted within {timeout} cycles")
            continue
        
        actual = int(dut.result.value)
        print(f"Actual: {actual}")
        
        if actual == expected:
            print("PASSED")
            passed += 1
        else:
            print(f"FAILED: Expected {expected}, got {actual}")
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed} out of {total} tests passed"
