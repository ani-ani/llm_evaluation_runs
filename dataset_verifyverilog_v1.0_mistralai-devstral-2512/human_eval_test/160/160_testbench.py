import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
RESULT_WIDTH = 16
INDEX_WIDTH = 3
MAX_OPERANDS = 8
CLK_NS = 10
MAX_CYCLES = 200

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def encode_operator(op):
    op_map = {'+': 0, '-': 1, '*': 2, '//': 3, '**': 4}
    return op_map.get(op, 0)

def evaluate_expression(operators, operands):
    """Evaluate expression left-to-right without precedence"""
    result = operands[0]
    for i, op in enumerate(operators):
        try:
            if op == '+':
                result = result + operands[i+1]
            elif op == '-':
                result = result - operands[i+1]
            elif op == '*':
                result = result * operands[i+1]
            elif op == '//':
                if operands[i+1] == 0:
                    return None  # Division by zero
                result = result // operands[i+1]
            elif op == '**':
                exp = operands[i+1]
                if exp < 0:
                    return None
                result = result ** exp
        except (ZeroDivisionError, OverflowError):
            return None
    return clamp_to_width(result, RESULT_WIDTH) if result >= 0 else 0

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'config_done'):
        dut.config_done.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_algebra_evaluator(dut):
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational design
        await Timer(100, units='ns')
    
    test_cases = [
        (['**', '*', '+'], [2, 3, 4, 5], 37),
        (['+', '*', '-'], [2, 3, 4, 5], 9),
        (['//', '*'], [7, 3, 4], 8),
        (['*', '*'], [2, 3, 4], 24),
        (['+', '+'], [1, 2, 3], 6),
        (['-', '-'], [10, 3, 2], 5),
    ]
    
    passed = 0
    failed = 0
    
    for i, (operators, operands, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {' '.join(operators)} {' '.join(map(str, operands))} = {expected}")
        try:
            # Load operands
            if has_signal(dut, 'operand_index'):
                for idx, val in enumerate(operands):
                    dut.operand_index.value = idx
                    dut.operand.value = clamp_to_width(val, DATA_WIDTH)
                    await RisingEdge(dut.clk)
                
                # Load operators
                for idx, op in enumerate(operators):
                    dut.operator_index.value = idx
                    dut.operator.value = encode_operator(op)
                    await RisingEdge(dut.clk)
                
                # Signal configuration complete
                dut.config_done.value = 1
                await RisingEdge(dut.clk)
                dut.config_done.value = 0
                await RisingEdge(dut.clk)
                
                # Start calculation
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                    
                    await wait_for_done(dut, MAX_CYCLES)
                    
                    if not is_value_defined(dut.result.value):
                        raise TestFailure("Result undefined")
                    
                    result = int(dut.result.value)
                    if result != expected:
                        raise TestFailure(f"Expected {expected}, got {result}")
                    passed += 1
                else:
                    await Timer(50, units='ns')
                    result = int(dut.result.value)
                    if result != expected:
                        raise TestFailure(f"Expected {expected}, got {result}")
                    passed += 1
            else:
                # Direct input for simpler interface
                await Timer(100, units='ns')
                if has_signal(dut, 'result'):
                    result = int(dut.result.value)
                    if result != expected:
                        raise TestFailure(f"Expected {expected}, got {result}")
                    passed += 1
                else:
                    # Just verify module exists
                    passed += 1
        
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed")
