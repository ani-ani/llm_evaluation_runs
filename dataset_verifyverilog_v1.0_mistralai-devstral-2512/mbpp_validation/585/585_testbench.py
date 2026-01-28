import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Fixed-point conversion (Q8.8)
def float_to_fixed(f, frac=16):
    # For Q8.8: 8 integer, 8 fractional = 16 bits total
    return int(f * (1 << 8))

def fixed_to_float(v, frac=16):
    return v / (1 << 8)

# ASCII to 8-byte packed
def pack_name(name_str):
    # Pad to 8 chars with spaces
    padded = name_str.ljust(8, ' ')
    packed = 0
    for i, c in enumerate(padded[:8]):
        packed |= (ord(c) & 0xFF) << (56 - i*8)
    return packed

def write_item(dut, idx, name, price, clk):
    # Pack name and price
    name_packed = pack_name(name)
    price_fixed = float_to_fixed(price)
    
    # Assign inputs
    dut.item_data.value = name_packed
    dut.item_price.value = price_fixed
    dut.item_index.value = idx
    dut.items_valid.value = 1
    
    # Pulse clock
    await RisingEdge(clk)
    dut.items_valid.value = 0

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    dut.items_valid.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=256):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_expensive_items(dut):
    # Setup clock
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (items_list, n, expected_top_n_prices)
    test_cases = [
        # Test 1: 2 items, n=1, highest price
        (
            [
                {'name': 'Item-1', 'price': 101.1},
                {'name': 'Item-2', 'price': 555.22}
            ],
            1,
            [555.22]
        ),
        # Test 2: 3 items, n=2, top 2 prices
        (
            [
                {'name': 'Item-1', 'price': 101.1},
                {'name': 'Item-2', 'price': 555.22},
                {'name': 'Item-3', 'price': 45.09}
            ],
            2,
            [555.22, 101.1]
        ),
        # Test 3: 4 items, n=1, highest price
        (
            [
                {'name': 'Item-1', 'price': 101.1},
                {'name': 'Item-2', 'price': 555.22},
                {'name': 'Item-3', 'price': 45.09},
                {'name': 'Item-4', 'price': 22.75}
            ],
            1,
            [555.22]
        )
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (items, n, expected_prices) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx+1}: {len(items)} items, n={n}")
        
        try:
            # Set n
            dut.n.value = n
            
            # Input items (cycles 0-15)
            for i, item in enumerate(items):
                await write_item(dut, i, item['name'], item['price'], dut.clk)
            
            # Fill remaining with invalid
            for i in range(len(items), 16):
                dut.items_valid.value = 0
                dut.item_index.value = i
                await RisingEdge(dut.clk)
            
            # Start processing
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            result_prices = []
            for i in range(8):
                # Check if result port exists
                if has_signal(dut, f'result_price[{i}]'):
                    port = getattr(dut, f'result_price[{i}]')
                    if is_value_defined(port.value):
                        val = int(port.value)
                        # Convert fixed to float for comparison
                        price_f = val / 256.0  # Q8.8 -> divide by 2^8
                        result_prices.append(price_f)
                else:
                    break
            
            # Compare with expected (only check first n results)
            for i in range(n):
                if i >= len(result_prices):
                    raise TestFailure(f"Missing result for position {i}")
                
                exp_price = expected_prices[i]
                got_price = result_prices[i]
                
                # Allow small floating-point error
                if abs(exp_price - got_price) > 0.5:
                    raise TestFailure(f"Position {i}: Expected {exp_price:.2f}, got {got_price:.2f}")
            
            cocotb.log.info(f"Test {test_idx+1} passed")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"Test {test_idx+1} FAILED: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")
