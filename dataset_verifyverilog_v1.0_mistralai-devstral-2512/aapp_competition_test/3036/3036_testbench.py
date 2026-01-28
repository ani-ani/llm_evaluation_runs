import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_chef(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Helper to load data
    async def load_brands(brand_counts):
        if has_signal(dut, 'load_brands'):
            dut.load_brands.value = 1
            await RisingEdge(dut.clk)
            dut.load_brands.value = 0
        for i, count in enumerate(brand_counts):
            if has_signal(dut, 'data_in'):
                dut.data_in.value = clamp_to_width(count, 8)
            if has_signal(dut, 'addr'):
                dut.addr.value = clamp_to_width(i+1, 8)  # ingredient IDs start at 1
            await RisingEdge(dut.clk)
    
    async def load_dish(idx, ingredients):
        if has_signal(dut, 'load_dish'):
            dut.load_dish.value = 1
            await RisingEdge(dut.clk)
            dut.load_dish.value = 0
        for i, ing in enumerate(ingredients):
            if has_signal(dut, 'data_in'):
                dut.data_in.value = clamp_to_width(ing, 8)
            if has_signal(dut, 'addr'):
                dut.addr.value = clamp_to_width(idx, 8)
            await RisingEdge(dut.clk)
    
    async def load_compat(pairs):
        if has_signal(dut, 'load_compat'):
            dut.load_compat.value = 1
            await RisingEdge(dut.clk)
            dut.load_compat.value = 0
        for a, b in pairs:
            if has_signal(dut, 'data_in'):
                dut.data_in.value = clamp_to_width(a, 8)
            if has_signal(dut, 'addr'):
                dut.addr.value = clamp_to_width(b, 8)
            await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # Input 1: 6 1 1 1 0
        {
            'brands': [2, 3, 1, 5, 3, 2],
            'dishes': [
                [1, 2],      # Starter 0: ingredients 1,2
                [3, 4, 5],   # Main 0: ingredients 3,4,5
                [6]          # Dessert 0: ingredient 6
            ],
            'incompat': [],
            'expected': 180
        },
        # Input 2: 3 2 2 1 1
        {
            'brands': [2, 3, 2],
            'dishes': [
                [1],         # Starter 0
                [2],         # Starter 1
                [2],         # Main 0
                [3],         # Main 1
                [1]          # Dessert 0
            ],
            'incompat': [[2, 3]],  # Dish 2 (Main 0) and Dish 3 (Main 1) - invalid per problem
            'expected': 0  # Invalid input per problem statement (must be different types)
        },
        # Input 3: 3 1 1 1 1
        {
            'brands': [5, 5, 5],
            'dishes': [
                [1, 2, 3],  # Starter 0
                [1, 2, 3],  # Main 0
                [1, 2, 3]   # Dessert 0
            ],
            'incompat': [[1, 2]],  # Starter 0 and Main 0
            'expected': 0
        },
    ]
    
    for test_idx, test in enumerate(test_cases):
        cocotb.log.info(f"\n--- Test Case {test_idx+1} ---")
        
        # Reset
        if is_seq:
            dut.rst_n.value = 0
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
        
        # Load data
        await load_brands(test['brands'])
        
        s = 0
        m = 0
        d = 0
        for i, dish in enumerate(test['dishes']):
            await load_dish(i, dish)
        
        await load_compat(test['incompat'])
        
        # Start computation
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        
        # Wait for done
        if is_seq:
            timeout = 2000
            for _ in range(timeout):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
            else:
                raise TestFailure(f"Timeout waiting for done")
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result undefined")
        
        result = int(dut.result.value)
        expected = test['expected']
        
        if result == 0xFFFFFFFF:
            result_str = "too many"
        else:
            result_str = str(result)
        
        if result_str != str(expected):
            raise TestFailure(f"Expected {expected}, got {result_str}")
        
        cocotb.log.info(f"Result: {result_str}")

    cocotb.log.info("All tests passed!")