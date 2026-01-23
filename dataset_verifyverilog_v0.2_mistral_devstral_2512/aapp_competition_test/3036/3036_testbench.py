import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

def to_fixed_point(value, bits=16):
    return int(value * (1 << bits))

@cocotb.test()
async def test_chef_dinner_counter_1(dut):
    """Test Sample Input 1: 6 1 1 1 0, brands 2,3,1,5,3,2, dishes with ingredients 1-2, 3-4-5, 6, expected 180"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Set inputs
    dut.r_num.value = 6
    dut.s_num.value = 1
    dut.m_num.value = 1
    dut.d_num.value = 1
    dut.n_num.value = 0
    
    # Brands for 6 ingredients
    brands = [2, 3, 1, 5, 3, 2]
    for i in range(16):
        dut.brands[i].value = brands[i] if i < 6 else 0
    
    # Dishes: starter has 2 ingredients (1,2), main has 3 (3,4,5), dessert has 1 (6)
    dish_ing_count = [2, 3, 1] + [0]*21
    for i in range(24):
        dut.dish_ing_count[i].value = dish_ing_count[i]
    
    # Dish ingredients flattened: dish0: 1,2; dish1: 3,4,5; dish2: 6
    dish_ingredients = [1, 2, 3, 4, 5, 6] + [0]*186
    for i in range(192):
        dut.dish_ingredients[i].value = dish_ingredients[i]
    
    # No incompatibilities
    for i in range(16):
        dut.incompat_dish1[i].value = 0
        dut.incompat_dish2[i].value = 0
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 2000 cycles or until done)
    cycles = 0
    while not dut.done.value and cycles < 2100:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if not dut.done.value:
        raise TestFailure(f"Module did not complete within 2100 cycles")
    
    # Expected: 1 product = 2*3*1*5*3*2 = 180
    expected = 180
    if dut.result.value != expected:
        raise TestFailure(f"Expected {expected}, got {dut.result.value}")
    if dut.too_many_flag.value != 0:
        raise TestFailure(f"too_many_flag should be 0")

@cocotb.test()
async def test_chef_dinner_counter_2(dut):
    """Test Sample Input 2: 3 2 2 1 1, brands 2,3,2, complex incompatibilities, expected 22"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Set inputs
    dut.r_num.value = 3
    dut.s_num.value = 2
    dut.m_num.value = 2
    dut.d_num.value = 1
    dut.n_num.value = 1
    
    # Brands for 3 ingredients
    brands = [2, 3, 2]
    for i in range(16):
        dut.brands[i].value = brands[i] if i < 3 else 0
    
    # Dishes (5 total): s0(ing1), s1(ing2), m0(ing2), m1(ing3), d0(ing1)
    # Indices: 0,1 start; 2,3 main; 4 dessert
    dish_ing_count = [1, 1, 1, 1, 1] + [0]*19
    for i in range(24):
        dut.dish_ing_count[i].value = dish_ing_count[i]
    
    # Ingredients: dish0:1, dish1:2, dish2:2, dish3:3, dish4:1
    dish_ingredients = [1, 2, 2, 3, 1] + [0]*187
    for i in range(192):
        dut.dish_ingredients[i].value = dish_ingredients[i]
    
    # Incompatibility: dish2 and dish4 (indices 2 and 4) -> 2,4
    dut.incompat_dish1[0].value = 2
    dut.incompat_dish2[0].value = 4
    for i in range(1, 16):
        dut.incompat_dish1[i].value = 0
        dut.incompat_dish2[i].value = 0
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    cycles = 0
    while not dut.done.value and cycles < 2100:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if not dut.done.value:
        raise TestFailure(f"Module did not complete within 2100 cycles")
    
    # Expected: 22
    expected = 22
    if dut.result.value != expected:
        raise TestFailure(f"Expected {expected}, got {dut.result.value}")
    if dut.too_many_flag.value != 0:
        raise TestFailure(f"too_many_flag should be 0")

@cocotb.test()
async def test_chef_dinner_counter_3(dut):
    """Test Sample Input 3: incompatibility blocks all, expected 0"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Set inputs
    dut.r_num.value = 3
    dut.s_num.value = 1
    dut.m_num.value = 1
    dut.d_num.value = 1
    dut.n_num.value = 1
    
    # Brands 5,5,5
    brands = [5, 5, 5]
    for i in range(16):
        dut.brands[i].value = brands[i] if i < 3 else 0
    
    # All dishes have same 3 ingredients
    dish_ing_count = [3, 3, 3] + [0]*21
    for i in range(24):
        dut.dish_ing_count[i].value = dish_ing_count[i]
    
    # Ingredients for all 3 dishes: 1,2,3
    dish_ingredients = [1,2,3, 1,2,3, 1,2,3] + [0]*183
    for i in range(192):
        dut.dish_ingredients[i].value = dish_ingredients[i]
    
    # Incompatibility: dish0 and dish2 (start and dessert) -> 0,2
    # Note: input uses 1-based indexing, we use 0-based
    dut.incompat_dish1[0].value = 0
    dut.incompat_dish2[0].value = 2
    for i in range(1, 16):
        dut.incompat_dish1[i].value = 0
        dut.incompat_dish2[i].value = 0
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    cycles = 0
    while not dut.done.value and cycles < 2100:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if not dut.done.value:
        raise TestFailure(f"Module did not complete within 2100 cycles")
    
    # Expected: 0 (all blocked)
    expected = 0
    if dut.result.value != expected:
        raise TestFailure(f"Expected {expected}, got {dut.result.value}")
    if dut.too_many_flag.value != 0:
        raise TestFailure(f"too_many_flag should be 0")

@cocotb.test()
async def test_chef_dinner_counter_overflow(dut):
    """Test that overflow detection works (product > 1,000,000)"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Set inputs for overflow: many large brands
    dut.r_num.value = 16
    dut.s_num.value = 1
    dut.m_num.value = 1
    dut.d_num.value = 1
    dut.n_num.value = 0
    
    # All brands = 100 (max)
    for i in range(16):
        dut.brands[i].value = 100
    
    # Dish uses all 16 ingredients
    dish_ing_count = [16, 16, 16] + [0]*21
    for i in range(24):
        dut.dish_ing_count[i].value = dish_ing_count[i]
    
    # All ingredients 1-16 in each dish
    dish_ingredients = list(range(1, 17)) + list(range(1, 17)) + list(range(1, 17)) + [0]*144
    for i in range(192):
        dut.dish_ingredients[i].value = dish_ingredients[i]
    
    # No incompatibilities
    for i in range(16):
        dut.incompat_dish1[i].value = 0
        dut.incompat_dish2[i].value = 0
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    cycles = 0
    while not dut.done.value and cycles < 2100:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if not dut.done.value:
        raise TestFailure(f"Module did not complete within 2100 cycles")
    
    # Expected: product is 100^16 which is 10^32 >> 10^6, so should be 0 with flag
    if dut.result.value != 0:
        raise TestFailure(f"Expected 0 due to overflow, got {dut.result.value}")
    if dut.too_many_flag.value != 1:
        raise TestFailure(f"too_many_flag should be 1 for overflow")

@cocotb.test()
async def test_chef_dinner_counter_small_complex(dut):
    """Test with small values, multiple triplets"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 2 start, 2 main, 2 dessert, no incompat
    dut.r_num.value = 2
    dut.s_num.value = 2
    dut.m_num.value = 2
    dut.d_num.value = 2
    dut.n_num.value = 0
    
    # Brands
    dut.brands[0].value = 2
    dut.brands[1].value = 3
    for i in range(2, 16):
        dut.brands[i].value = 0
    
    # Dishes: 4 total
    # s0: ing1, s1: ing2
    # m0: ing1, m1: ing2
    # d0: ing1, d1: ing2
    dish_ing_count = [1, 1, 1, 1, 1, 1] + [0]*18
    for i in range(24):
        dut.dish_ing_count[i].value = dish_ing_count[i]
    
    dish_ingredients = [1, 2, 1, 2, 1, 2] + [0]*186
    for i in range(192):
        dut.dish_ingredients[i].value = dish_ingredients[i]
    
    # No incompat
    for i in range(16):
        dut.incompat_dish1[i].value = 0
        dut.incompat_dish2[i].value = 0
    
    # Start
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    cycles = 0
    while not dut.done.value and cycles < 2100:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if not dut.done.value:
        raise TestFailure(f"Module did not complete within 2100 cycles")
    
    # Triplets: 2*2*2 = 8 total
    # 2 with ing1 in all (product 2) -> 4?
    # No, triplet: s0 m0 d0: ing1 in all -> 2
    # s0 m0 d1: ing1 in s0,m0, ing2 in d1 -> 2*3=6
    # s0 m1 d0: ing1 in s0,d0, ing2 in m1 -> 2*3=6
    # s0 m1 d1: ing1 in s0, ing2 in m1,d1 -> 3
    # s1 m0 d0: ing2 in s1, ing1 in m0,d0 -> 3*2=6
    # s1 m0 d1: ing2 in s1,d1, ing1 in m0 -> 3*2=6
    # s1 m1 d0: ing2 in s1,m1, ing1 in d0 -> 3*2=6
    # s1 m1 d1: ing2 in all -> 3
    # Sum: 2+6+6+3+6+6+6+3 = 38
    expected = 38
    if dut.result.value != expected:
        raise TestFailure(f"Expected {expected}, got {dut.result.value}")
    if dut.too_many_flag.value != 0:
        raise TestFailure(f"too_many_flag should be 0")

print("COCOTB TESTS DEFINED")