import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except (ValueError, TypeError): return False

def safe_int(v, default=0):
    try: return int(v)
    except (ValueError, TypeError): return default

def clamp_to_width(v, bits):
    if bits >= 32: return v & 0xFFFFFFFF # Assume 32-bit max for simulation
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        if has_signal(dut, 'done'):
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                return True
        await RisingEdge(dut.clk)
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'grid_valid'): dut.grid_valid.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def parse_input_to_grid(input_str):
    lines = input_str.strip().split('\n')
    h, w = map(int, lines[0].split())
    grid = []
    for i in range(1, 1 + h):
        row = list(map(int, lines[i].split()))
        grid.append(row)
    src_i, src_j = map(int, lines[1 + h].split())
    return h, w, grid, src_i - 1, src_j - 1  # Convert to 0-indexed

def calculate_expected(h, w, grid, src_i, src_j):
    # BFS to find connected components of strictly decreasing path
    visited = [[False for _ in range(w)] for _ in range(h)]
    queue = [(src_i, src_j)]
    visited[src_i][src_j] = True
    total_volume = 0
    
    # Direction offsets for 8 neighbors
    dirs = [(-1,-1), (-1,0), (-1,1), (0,-1), (0,1), (1,-1), (1,0), (1,1)]
    
    while queue:
        r, c = queue.pop(0)
        # Only count volume if it's water (negative altitude)
        if grid[r][c] < 0:
            total_volume += -grid[r][c]
        
        for dr, dc in dirs:
            nr, nc = r + dr, c + dc
            if 0 <= nr < h and 0 <= nc < w:
                if not visited[nr][nc]:
                    # Water flows to lower ground. 
                    # So if we are at (r,c) with level L, we can drain (nr,nc) if it is < L.
                    # Note: The source is the drainage point. Water flows TO the source.
                    # So we look for paths from source outwards where altitudes increase? 
                    # No, water sits in depressions. 
                    # The problem says: "Water respects gravity, so it can only flow closer to the Earth’s core – either via the drainage device or to a neighbouring square with a lower water level."
                    # "lower water level" means lower altitude (more negative) or lower absolute level?
                    # "Squares with negative altitude are covered by water."
                    # If the device is at (src), it drains everything that can flow to it.
                    # Water flows from higher elevation to lower elevation.
                    # If A is at -5m and B is at -2m, water flows from B to A (A is deeper/closer to core).
                    # Wait. Water sits on top of land. 
                    # If land is at -5m, water level is -5m (or higher).
                    # If we drain it, the water disappears.
                    # The condition "lower water level" likely means lower altitude value.
                    # So if we are at cell (r,c), we can drain neighbor (nr,nc) if altitude(nr,nc) < altitude(r,c).
                    # Example: -5 (src) < -2. So water flows from -2 to -5? 
                    # If -2 is connected to -5, yes, water drains.
                    # Let's check sample 1:
                    # Grid:
                    # -5  2 -5
                    # -1 -2 -1
                    #  5  4 -5
                    # Source: (1,1) -> value -2.
                    # Neighbors of -2: -5 (0,0), 2 (0,1), -5 (0,2), -1 (1,0), -1 (1,2), 5 (2,0), 4 (2,1), -5 (2,2).
                    # Which of these can flow to -2? 
                    # Water flows to LOWER altitude.
                    # -1 > -2. Water flows from -1 to -2. (Volume 1)
                    # -5 < -2. Water is deeper at -5. It stays there unless it flows to -2? No, -5 is lower, water flows from -2 to -5.
                    # Ah, the device is at -2. It drains water.
                    # Water is only present where altitude < 0.
                    # Water flows to lower neighbor.
                    # If neighbor is lower (e.g. -5 < -2), water can flow there.
                    # But we are draining FROM (1,1).
                    # This implies we are pumping water out.
                    # The problem says: "Water respects gravity, so it can only flow closer to the Earth’s core – either via the drainage device or to a neighbouring square with a lower water level."
                    # If I drain at (1,1), I lower the water level there.
                    # Water from neighbors flows into (1,1) if (1,1) is lower than the neighbor.
                    # So we need to find all cells that can reach the source via a path of strictly decreasing altitudes (or equal? usually strictly for flow).
                    # Let's assume strictly decreasing: dest < src.
                    # We start at source (dest).
                    # We look for neighbors that are HIGHER than source (so water can flow down to source).
                    # Wait. "Water flows to... a neighbouring square with a lower water level."
                    # Lower water level means numerically smaller (more negative).
                    # So if I have A (-2) and B (-5), B is lower.
                    # Water flows A -> B.
                    # If the device is at A (-2), it cannot receive water from B (-5) because B is lower.
                    # It can receive from C (-1) because -1 > -2 (C is higher).
                    # So the algorithm is:
                    # Start from source.
                    # Find all reachable cells where we can trace a path BACK to source such that altitudes are strictly increasing along the path.
                    # i.e. path: Cell -> Neigh -> ... -> Source.
                    # Alt(Cell) > Alt(Neigh) > ... > Alt(Source).
                    # So from Source, we flood fill to neighbors strictly HIGHER than current.
                    
                    if grid[nr][nc] > grid[r][c]:
                        visited[nr][nc] = True
                        queue.append((nr, nc))
    
    # Sum volume of all visited cells that are water (alt < 0)
    vol = 0
    for r in range(h):
        for c in range(w):
            if visited[r][c] and grid[r][c] < 0:
                vol += -grid[r][c]
    return vol

# Testbench
@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_drain_baltic(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    test_inputs = [
        "3 3\n-5 2 -5\n-1 -2 -1\n5 4 -5\n2 2\n",
        "2 3\n-2 -3 -4\n-3 -2 -3\n2 1\n"
    ]
    
    passed = 0
    failed = 0

    for idx, input_str in enumerate(test_inputs):
        cocotb.log.info(f"Running Test Case {idx+1}")
        h, w, grid, src_i, src_j = parse_input_to_grid(input_str)
        expected = calculate_expected(h, w, grid, src_i, src_j)
        
        # Check grid size constraints
        if h > 16 or w > 16:
            cocotb.log.warning(f"Grid size {h}x{w} exceeds hardware limit 16x16. Truncating.")
            h = min(h, 16)
            w = min(w, 16)

        try:
            # 1. Load Source Position
            if has_signal(dut, 'source_row'):
                dut.source_row.value = src_i
                dut.source_col.value = src_j
            
            # 2. Load Grid Data
            # Assuming row-major order input stream
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Stream in the grid
                for r in range(h):
                    for c in range(w):
                        dut.grid_data.value = grid[r][c]
                        dut.grid_valid.value = 1
                        await RisingEdge(dut.clk)
                dut.grid_valid.value = 0
            else:
                # Combinational logic - just set inputs directly
                # This testbench assumes sequential implementation as per spec
                pass
            
            # 3. Wait for Done
            if is_seq:
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # 4. Check Result
            if has_signal(dut, 'drained_volume'):
                result = int(dut.drained_volume.value)
                if result != expected:
                    raise TestFailure(f"Test {idx+1} Failed: Expected {expected}, Got {result}")
            else:
                raise TestFailure("Signal 'drained_volume' not found")
                
            passed += 1
            cocotb.log.info(f"Test {idx+1} Passed: Result {result}")
            
        except TestFailure as e:
            cocotb.log.error(str(e))
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
