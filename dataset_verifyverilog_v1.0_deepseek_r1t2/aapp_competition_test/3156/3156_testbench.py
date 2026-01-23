import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
MAX_STORES = 8
MAX_ITEMS = 16
ITEM_ID_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Item to store mapping (combinational LUT simulation)
item_store_map = {
    0: {0, 2},  # chocolate
    1: {1},      # icecream
    2: {2},      # cookies
    # For third test: tomatoes, cucumber, salad, mustard, salt
    # We'll map items to IDs: tomatoes=0, cucumber=1, salad=2, mustard=3, salt=4
}

# Invert for LUT: item_id -> store_mask
lut_store_mask = {}
for item_id, stores in item_store_map.items():
    mask = 0
    for store in stores:
        mask |= (1 << store)
    lut_store_mask[item_id] = mask

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# Map string items to IDs for test
def item_to_id(name):
    mapping = {
        'chocolate': 0,
        'icecream': 1,
        'cookies': 2,
        'tomatoes': 3,
        'cucumber': 4,
        'salad': 5,
        'mustard': 6,
        'salt': 7,
    }
    return mapping.get(name, 0)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_shopping_path(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Wait for clock to stabilize
    await Timer(100, units='ns')
    
    # Test cases: (shopping_list, list_length, expected_result, description)
    test_cases = [
        # Test 1: impossible
        ([0, 2, 1], 3, 0, "impossible: chocolate, cookies, icecream - order wrong"),
        # Test 2: unique
        ([0, 1, 2], 3, 1, "unique: chocolate, icecream, cookies - correct order"),
        # Test 3: ambiguous - need to set up proper mapping
        # We'll use different item IDs: 3=tomatoes, 4=cucumber, 5=salad, 6=mustard, 7=salt
        ([3, 4, 5, 6, 7], 5, 2, "ambiguous: multiple paths"),
    ]
    
    # Update LUT for test 3
    global lut_store_mask
    lut_store_mask = {
        3: 0b00000101,  # tomatoes: stores 0,2
        4: 0b00000110,  # cucumber: stores 1,2
        5: 0b00000100,  # salad: store 2
        6: 0b00000111,  # mustard: stores 0,1,2
        7: 0b00000011,  # salt: stores 0,1
    }
    
    for i, (shopping_list_ids, list_len, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {desc}")
        
        # Reset DUT
        await reset_dut(dut)
        
        # Write shopping list
        for j in range(MAX_ITEMS):
            if j < list_len:
                dut.shopping_list[j].value = shopping_list_ids[j]
            else:
                dut.shopping_list[j].value = 0
        
        dut.list_length.value = list_len
        
        # Create a coroutine to handle LUT responses
        async def lut_handler():
            while True:
                await RisingEdge(dut.item_id_for_lut)
                await Timer(1, units='ns')  # Combinational delay
                item_id = int(dut.item_id_for_lut.value)
                if item_id in lut_store_mask:
                    dut.store_mask.value = lut_store_mask[item_id]
                else:
                    dut.store_mask.value = 0
        
        # Start LUT handler
        lut_task = cocotb.start_soon(lut_handler())
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        result = int(dut.result.value)
        
        # Cancel LUT handler
        lut_task.kill()
        
        # Verify
        if result != expected:
            raise TestFailure(f"Test {i+1} failed: expected {expected}, got {result}")
        
        cocotb.log.info(f"  PASS: result = {result}")
    
    cocotb.log.info("\n" + "="*50)
    cocotb.log.info("All tests passed!")
