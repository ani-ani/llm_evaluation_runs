module superdoku_solver (
    input clk,
    input rst_n,
    input start,
    input [1:0] k,
    input [1:0] row_idx,
    input [1:0] cell_idx,
    input [1:0] data_in,
    output reg [1:0] grid_out [0:3][0:3],
    output reg valid,
    output reg solvable,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam CHECK_INPUT = 3'b010;
    localparam GENERATE = 3'b011;
    localparam VERIFY = 3'b100;
    localparam DONE_STATE = 3'b101;

    reg [2:0] state, next_state;
    
    // Internal registers
    reg [1:0] grid [0:3][0:3];
    reg [2:0] counter; // General purpose counter
    reg [1:0] temp_row [0:3]; // Temporary storage for shifting
    reg [1:0] row_check; // Row index for verification
    reg [1:0] col_check; // Column index for verification
    reg [1:0] value_check; // Value being checked (1-4)
    reg temp_valid;
    
    // Input loading counter
    reg [1:0] load_count;
    reg [1:0] input_row_idx;
    reg [1:0] input_cell_idx;
    reg [1:0] input_data_reg;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    if (k == 2'b00) next_state = GENERATE;
                    else next_state = LOAD;
                end
            end
            LOAD: begin
                if (load_count == k) begin
                    next_state = CHECK_INPUT;
                end
            end
            CHECK_INPUT: begin
                if (counter >= 3'd4 * k) begin // Check all cells of k rows
                    next_state = GENERATE;
                end
            end
            GENERATE: begin
                if (counter == 3'd4) begin // 4 cycles for shift generation
                    next_state = VERIFY;
                end
            end
            VERIFY: begin
                if (row_check == 4 && col_check == 0 && value_check == 4) begin
                    next_state = DONE_STATE;
                end
            end
            DONE_STATE: begin
                // Stay here until reset
                next_state = DONE_STATE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all outputs and internal state
            valid <= 1'b0;
            solvable <= 1'b0;
            done <= 1'b0;
            counter <= 3'd0;
            load_count <= 2'b00;
            temp_valid <= 1'b1;
            row_check <= 2'b00;
            col_check <= 2'b00;
            value_check <= 2'b00;
            // Clear grid
            integer i, j;
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 4; j = j + 1) begin
                    grid[i][j] <= 2'b00;
                    grid_out[i][j] <= 2'b00;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        load_count <= 2'b00;
                        counter <= 3'd0;
                        temp_valid <= 1'b1;
                        done <= 1'b0;
                        // If k=0, initialize default row 0 (1,2,3,4 -> 00,01,10,11)
                        if (k == 2'b00) begin
                            grid[0][0] <= 2'b00; // 1
                            grid[0][1] <= 2'b01; // 2
                            grid[0][2] <= 2'b10; // 3
                            grid[0][3] <= 2'b11; // 4
                        end
                    end
                end
                
                LOAD: begin
                    // Load input data based on row_idx and cell_idx
                    // This happens for k cycles (or fewer if user provides multiple cells per cycle)
                    // We assume valid data arrives when state is LOAD
                    // To match timing: user supplies data for 4*k cycles or k cycles with 4 cells
                    // Spec says: "Load first k rows into grid[0][k-1]"
                    // And "Timing: 12 clock cycles from start to done (LOAD=4, CHECK=3...)"
                    // This implies LOAD takes 4 cycles total (for all k rows?)
                    // Or LOAD=4 means 4 cycles for input regardless of k?
                    // Let's use the inputs directly as they come.
                    // We need to load k rows. If k=4, 4 rows of 4 cells = 16 inputs.
                    // But timing says LOAD=4. This is ambiguous.
                    // Hypothesis: Inputs are streamed in 1 cycle per cell for k rows.
                    // LOAD=4 suggests maybe we only wait 4 cycles? 
                    // Or maybe k is always 4? No, "k=0-4".
                    // Re-read: "Timing: 12 clock cycles ... (LOAD=4, CHECK=3, GENERATE=3, VERIFY=2)"
                    // Total 4+3+3+2 = 12.
                    // If k=4, we can't load 16 cells in 4 cycles unless input is parallel or 4 cells/cycle.
                    // However, inputs are row_idx, cell_idx, data_in.
                    // Let's assume the user asserts valid inputs during LOAD state.
                    // To fit the 4 cycle constraint for LOAD state, we might need to assume user 
                    // does the loading fast or we just wait 4 cycles.
                    // Implementation: Since inputs are provided, we just latch them when valid.
                    // But we need to increment load_count somehow.
                    // Let's assume for simplicity that load_count increments on valid input.
                    // To satisfy the specific 4 cycle requirement for the state machine, 
                    // we will treat LOAD state as a waiting period where inputs are accepted.
                    // Actually, "k cycles" is mentioned in description.
                    // Let's look at the counter usage. 
                    // If LOAD state logic requires k cycles, and total LOAD phase is 4 cycles.
                    // Maybe k is always 4? No.
                    // Let's stick to: State stays in LOAD for a certain time.
                    // Since the user provides row_idx and cell_idx, we can just capture data 
                    // whenever the state is LOAD.
                    // Let's update load_count based on a pseudo-counter or assume input is ready.
                    // To make it fit 12 cycle total:
                    // LOAD=4 cycles. CHECK=3. GENERATE=3. VERIFY=2.
                    // If k=4, we load 16 cells. 4 cycles is not enough for 16 serial loads.
                    // Perhaps the problem implies we load 1 row per cycle? Or 4 cells in parallel?
                    // Given "row_idx, cell_idx", it seems addressable.
                    // Let's assume we just stay in LOAD for 4 cycles and the user sets inputs.
                    // We will increment load_count every cycle in LOAD.
                    // We will use the inputs row_idx, cell_idx, data_in directly.
                    // If k < 4, we will load fewer rows.
                    // Wait, "LOAD=4". If k=0, we skip LOAD.
                    // If k=1, we stay in LOAD for 4 cycles?
                    // Let's implement standard behavior:
                    // We capture data_in into grid[row_idx][cell_idx] when state is LOAD.
                    // We will count cycles in LOAD to manage the flow.
                    // However, to strictly follow "k cycles" description, 
                    // we should probably advance when we have processed k rows.
                    // Let's use the load_count to count how many rows we have processed.
                    // But we need to know when a row is "done".
                    // Given the ambiguity, we will implement a flexible loader.
                    // We will use a separate counter `load_timer`.
                    // Actually, let's look at CHECK_INPUT counter: "3 cycles".
                    // CHECK_INPUT checks "no duplicates in any row".
                    // Verifying 4 rows for duplicates takes 4*4 = 16 comparisons.
                    // 3 cycles is too short for 16 serial checks.
                    // Parallel check or partial check per cycle?
                    // This implies the hardware is pipelined or highly parallel.
                    // Or maybe the cycles count is just an estimate.
                    // Let's stick to the state machine flow and do our best to fit ops.
                    
                    // Implementation of LOAD:
                    // We will increment a timer. 
                    // We will latch data whenever input is valid (assumed always valid during LOAD).
                    // We need to fill grid.
                    // Let's use `load_count` to index the current cell we expect to fill if sequential.
                    // But user gives row_idx/cell_idx.
                    // Let's just rely on user input during LOAD state.
                    // We will also increment an internal counter to eventually leave LOAD.
                    // Wait, if we must leave LOAD in 4 cycles, and user has k rows.
                    // Let's ignore the 4 cycle limit for LOAD if k > 4? No.
                    // Let's assume for the purpose of this design, we process inputs.
                    // We will count the number of unique addresses received?
                    // Let's stick to: When in LOAD, if k > 0, we expect inputs.
                    // To manage the transition out of LOAD, we will use a cycle counter `cycle_cnt`.
                    // But the prompt says "k cycles".
                    // Let's use `load_count` to count the number of rows loaded.
                    // We need a way to know when a row is fully loaded.
                    // Since we have cell_idx, we can track if we've seen 0,1,2,3 for a row.
                    // This is getting complex. 
                    // Let's simplify: The timing (LOAD=4) is likely for the case k=4 and 1 cell per cycle is NOT expected.
                    // BUT, the interface has `row_idx, cell_idx, data_in`.
                    // This implies random access.
                    // Let's implement: State stays in LOAD for `k` cycles if we treat 1 cycle per row.
                    // Or wait, 4 cycles for LOAD. 
                    // Let's assume the user provides all inputs in parallel or we just wait.
                    // The most robust way: 
                    // We enter LOAD. We wait for a "load_done" signal. But there is none.
                    // We will count 4 cycles. During these cycles, we latch inputs.
                    // If k is small, we ignore extra inputs or just overwrite.
                    // If k is large (4), we need 16 inputs. 4 cycles is impossible.
                    // Re-evaluation: Maybe "12 clock cycles total" is just a guideline and we are to design the logic.
                    // But "Timing: 12 clock cycles from start to done (LOAD=4...)" is very specific.
                    // Let's assume the LOAD phase takes 4 cycles, and we must load k rows.
                    // If k=4, this implies 4 rows are loaded in 4 cycles. 
                    // How? Maybe `data_in` is 8-bit? No, `data_in` is 2-bit.
                    // Maybe `row_idx` is not used, and we load row 0, then row 1 etc. sequentially.
                    // Let's implement: In LOAD, we expect `k` cycles of input.
                    // We'll use a counter `row_load_counter`.
                    // We'll wait for `row_load_counter < k`.
                    // To fit the 12 cycle total (with LOAD=4), if k=4, we load 1 row per cycle.
                    // But `cell_idx` is provided.
                    // Let's ignore `cell_idx` for a moment and assume we load 4 cells per cycle? 
                    // No, `data_in` is 2 bits.
                    // Let's assume the timing constraints are loose or meant for k=0..3.
                    // OR, the user provides `k` rows, but we only care about `row 0` to generate the rest!
                    // "Use row-shifting algorithm: if row i is given, shift it cyclically by i positions to generate subsequent rows"
                    // "Generate remaining rows using cyclic shift"
                    // "Row 0: as given"
                    // "Row 1: shift row 0..."
                    // THIS MEANS WE ONLY NEED ROW 0 TO GENERATE EVERYTHING.
                    // We only need to verify the *input* rows (row 0 to k-1).
                    // If k=4, we verify all 4 rows. But we only need row 0 for generation.
                    // The GENERATE step creates rows 1, 2, 3 (or more) from Row 0.
                    // If k=4, Row 0, 1, 2, 3 are given. We generate the same rows again?
                    // "Generate remaining rows". If k=4, there are 0 remaining rows.
                    // But the algorithm description says "Row 1: shift row 0..." etc. 
                    // This seems to imply the *solution* is always this specific shift pattern.
                    // So, regardless of k, we check the given rows against the shift pattern.
                    // Specifically:
                    // 1. Take Row 0 (given or default).
                    // 2. Generate Row 1' (shifted Row 0).
                    // 3. Generate Row 2' (shifted Row 0).
                    // 4. Generate Row 3' (shifted Row 0).
                    // 5. If k >= 2, check if Row 1 == Row 1'.
                    // 6. If k >= 3, check if Row 2 == Row 2'.
                    // 7. If k >= 4, check if Row 3 == Row 3'.
                    // This makes much more sense for a "Simplified" puzzle.
                    // The puzzle is solvable IF the given rows match the shift pattern.
                    // And IF Row 0 is a valid set (1-4 unique).
                    // And IF the generated grid (Row 0 shifted) is valid (cols are unique).
                    // Wait, "Row 1: shift row 0..." ensures ROWS are unique.
                    // Does it ensure COLS are unique?
                    // Row 0: 1, 2, 3, 4
                    // Row 1: 4, 1, 2, 3
                    // Row 2: 3, 4, 1, 2
                    // Row 3: 2, 3, 4, 1
                    // Cols: 
                    // Col 0: 1, 4, 3, 2 (Unique)
                    // Col 1: 2, 1, 4, 3 (Unique)
                    // Col 2: 3, 2, 1, 4 (Unique)
                    // Col 3: 4, 3, 2, 1 (Unique)
                    // So yes, shifting creates a Latin Square.
                    // So we just need to:
                    // 1. Load Row 0.
                    // 2. Load Rows 1 to k-1.
                    // 3. Check Row 0 for uniqueness.
                    // 4. Check if k>1, does Row 1 match shift(Row 0)?
                    // 5. Check if k>2, does Row 2 match shift^2(Row 0)?
                    // 6. Check if k>3, does Row 3 match shift^3(Row 0)?
                    // 7. If all match and Row 0 is unique, then Solvable.
                    // 8. Output the full grid.
                    
                    // Now, back to LOAD state.
                    // We need Row 0 and up to 3 other rows.
                    // We have `row_idx` and `cell_idx`.
                    // Timing: 4 cycles for LOAD.
                    // If k=4, we need 16 inputs.
                    // The only way 4 cycles works is if inputs are parallel or we process 4 cells per cycle.
                    // OR, the "12 clock cycles" is a minimum/typical and we are free to take more?
                    // "Timing: 12 clock cycles from start to done" -> Strict requirement.
                    // If strict, and we have 4 cycles for LOAD, we need to load 16 cells in 4 cycles.
                    // Is there a way? 
                    // Inputs: row_idx, cell_idx, data_in.
                    // If `row_idx` and `cell_idx` are used, it's random access.
                    // If we stay in LOAD for 4 cycles, and user sets ALL 16 inputs in those 4 cycles 
                    // (e.g. 4 per cycle via different signals, or just continuous updates),
                    // we need to latch them.
                    // Let's implement a loader that latches data whenever `start` is low (during LOAD) and data is valid.
                    // To be robust, we'll stay in LOAD for `k` cycles.
                    // Wait, the spec says "LOAD=4". 
                    // Let's make a decision: We will stay in LOAD for 4 cycles.
                    // We will accept input whenever state==LOAD.
                    // We will use a counter `cycle_in_load`.
                    // When `cycle_in_load` reaches `k`, we might move to next state?
                    // No, "LOAD=4" means the state takes 4 cycles.
                    // So we wait 4 cycles. 
                    // How do we load 16 cells in 4 cycles? 
                    // Maybe `data_in` is actually a vector? No, `[1:0] data_in`.
                    // Maybe we should ignore the "12 cycles" strictness and do it right.
                    // But "Your task is to generate an efficient Verilog module that meets the provided requirements."
                    // And "Timing: 12 clock cycles..." is a requirement.
                    // Okay, what if `k` is never 4? "k=0-4".
                    // If k=4, maybe we still only need Row 0 to generate solution.
                    // But we need to CHECK the other rows.
                    // Maybe the user provides the data via `row_idx`, `cell_idx`.
                    // If they provide it in 4 cycles (4 cells per cycle), that works.
                    // We need to handle the latching.
                    // Let's assume the user provides the data continuously. 
                    // We will latch `data_in` into `grid[row_idx][cell_idx]`.
                    // We will count how many unique rows we have fully loaded?
                    // No, let's just rely on the state duration.
                    // We will stay in LOAD for 4 cycles. 
                    // During these 4 cycles, we update the grid.
                    // After 4 cycles, we move to CHECK_INPUT.
                    // If k > 4, we have a problem. But we'll assume k <= 4.
                    // If k < 4, we might leave LOAD before we see data for rows 1,2,3.
                    // But we only need to check rows that exist.
                    // Let's refine LOAD: 
                    // Transition: next_state = (counter == 3'd4) ? CHECK_INPUT : LOAD;
                    // Counter increments every cycle in LOAD.
                    // In LOAD, we latch input: grid[row_idx][cell_idx] <= data_in;
                    // This handles random access. 
                    // If user inputs Row 0 in cycle 1, Row 1 in cycle 2, etc. (all 4 cells per row), it works.
                    
                    // CHECK_INPUT phase:
                    // We need to verify the given rows.
                    // 1. Row 0 must be unique (1,2,3,4).
                    // 2. If k>1, Row 1 must match shift(Row 0).
                    // 3. If k>2, Row 2 must match shift^2(Row 0).
                    // 4. If k>3, Row 3 must match shift^3(Row 0).
                    // We can do this in parallel or serial.
                    // Spec says CHECK=3 cycles.
                    // Let's break it down:
                    // Cycle 1: Check Row 0 uniqueness.
                    // Cycle 2: Check Row 1 vs shift(Row 0).
                    // Cycle 3: Check Row 2 vs shift^2(Row 0) AND Row 3 vs shift^3(Row 0)?
                    // Or just sequentially.
                    // Let's do: 
                    // CHECK_INPUT state uses a counter.
                    // We can store the result in `temp_valid`.
                    // If any check fails, `temp_valid` goes low.
                    
                    // GENERATE phase:
                    // Actually, GENERATE is just constructing the full grid.
                    // Even if k=4, we output the grid.
                    // We need to calculate the shifts.
                    // Row 0 is given.
                    // Row 1 = {grid[0][3], grid[0][0], grid[0][1], grid[0][2]}
                    // Row 2 = {grid[0][2], grid[0][3], grid[0][0], grid[0][1]}
                    // Row 3 = {grid[0][1], grid[0][2], grid[0][3], grid[0][0]}
                    // We can calculate this in 3 cycles (1 row per cycle).
                    // Counter 0: Row 1
                    // Counter 1: Row 2
                    // Counter 2: Row 3
                    // We need to write these to `grid` or `grid_out`.
                    // We should probably write to `grid` to have a consistent internal representation.
                    // Then copy to `grid_out` at the end.
                    
                    // VERIFY phase:
                    // Check columns of the full grid.
                    // Check that column j has {1,2,3,4}.
                    // Spec: VERIFY=2 cycles.
                    // 4 columns x 4 values = 16 checks.
                    // 2 cycles is tight.
                    // We can check 2 columns per cycle? Or specific logic.
                    // Let's check columns sequentially.
                    // We need to verify grid[0][j], grid[1][j], grid[2][j], grid[3][j] is a permutation of 0..3.
                    // We can use a valid flag. 
                    // We can iterate j from 0 to 3, and for each j, check values.
                    // To fit 2 cycles, we might need to check 2 columns per cycle.
                    // Or maybe verify just needs to happen, and we are done.
                    // We'll use the 2 cycles to iterate.
                    // Actually, let's just do it in 2 cycles for 4 columns.
                    // Cycle 1: Check Col 0 and Col 1.
                    // Cycle 2: Check Col 2 and Col 3.
                    // We need to check if all 4 values (1-4) exist in each column.
                    // We can use a 4-bit mask for each column.
                    // 0001 for value 1, 0010 for 2, 0100 for 3, 1000 for 4.
                    // If mask becomes 1111, column is valid.
                    // We need to accumulate this.
                    // In VERIFY state, we will check 2 columns per cycle.
                    // But we need to track which values we've seen.
                    // We can use registers to store the mask for all columns.
                    // Let's call them `col_mask_0`, `col_mask_1`, etc.
                    // Initialize to 0 in IDLE or VERIFY start.
                    // In VERIFY, we read the grid rows.
                    // We need 2 cycles. 
                    // Cycle 1: Update masks for Col 0 and Col 1 using Row 0..3.
                    // Wait, we can only access one row index at a time (mostly).
                    // We can use a loop counter `i` for rows.
                    // But we only have 2 cycles.
                    // To process 4 rows in 2 cycles, we might need to check 2 rows per cycle.
                    // Or just assume we have parallel access.
                    // Let's use a 2-bit row counter `verify_row`.
                    // In VERIFY state, we iterate `verify_row` from 0 to 3.
                    // If we do 2 rows per cycle, we are done in 2 cycles.
                    // Let's try: 
                    // Verify Row 0 and Row 1 in cycle 1.
                    // Verify Row 2 and Row 3 in cycle 2.
                    // Update masks. 
                    // At the end of cycle 2, check if all masks are 1111.
                    // 
                    // We need to store masks.
                    // `reg [3:0] col_masks [0:3];`
                    // Reset masks in IDLE or before VERIFY.
                    
                    // General strategy:
                    // Use `counter` for state-specific counters.
                    // Use `temp_valid` to store overall validity.
                    
                    // LOAD State:
                    // We stay here for 4 cycles.
                    // We update grid[row_idx][cell_idx] <= data_in.
                    // We count cycles with `counter`.
                    // When counter == 4, next_state = CHECK_INPUT.
                    // Wait, what if k=0? We skip LOAD. 
                    // In IDLE, if k==0, next_state = GENERATE.
                    
                    // CHECK_INPUT State:
                    // We need to verify rows 0..k-1.
                    // We can use `counter` to iterate through checks.
                    // We need to check Row 0 uniqueness.
                    // We need to check if Row 1 matches shift(Row 0), if k>1.
                    // We need to check if Row 2 matches shift^2(Row 0), if k>2.
                    // We need to check if Row 3 matches shift^3(Row 0), if k>3.
                    // Timing says 3 cycles.
                    // Cycle 1: Check Row 0 unique.
                    // Cycle 2: Check Row 1 shift.
                    // Cycle 3: Check Row 2 shift AND Row 3 shift.
                    // Or if k is small, we can skip.
                    // We can use `counter` to track which check we are doing.
                    // 0: Row 0 unique check.
                    // 1: Row 1 check.
                    // 2: Row 2 check.
                    // 3: Row 3 check.
                    // But timing is 3 cycles.
                    // Maybe we check Row 0 in cycle 0.
                    // Then in cycle 1, check Row 1.
                    // In cycle 2, check Row 2 and Row 3.
                    // Let's do that.
                    // We'll use a temp flag `temp_valid`.
                    // In CHECK_INPUT state, we start with `temp_valid` high (or keep it from LOAD).
                    // Actually, `temp_valid` will track failures.
                    // If `temp_valid` is low, we don't bother checking further.
                    // We can optimize: if `temp_valid` is high, perform checks.
                    
                    // GENERATE State:
                    // 3 cycles. 
                    // Counter 0: Row 1 = shift(Row 0).
                    // Counter 1: Row 2 = shift(Row 0).
                    // Counter 2: Row 3 = shift(Row 0).
                    // We write to `grid`.
                    // If k=0, Row 0 is default. We still generate Rows 1,2,3.
                    
                    // VERIFY State:
                    // 2 cycles.
                    // We need to verify columns.
                    // We need to check grid[0..3][0..3].
                    // We can do this efficiently.
                    // Let's prepare masks.
                    // We need to track which values have been seen in each column.
                    // We need registers for column masks.
                    // `col_mask_0`, `col_mask_1`, `col_mask_2`, `col_mask_3`.
                    // In VERIFY:
                    // We will iterate through rows.
                    // We can check 2 rows per cycle.
                    // Cycle 1 (verify_row=0,1):
                    // Update col masks based on grid[0] and grid[1].
                    // Cycle 2 (verify_row=2,3):
                    // Update col masks based on grid[2] and grid[3].
                    // Check if all masks are 1111.
                    // If yes, temp_valid = 1.
                    // If no, temp_valid = 0.
                    
                    // DONE State:
                    // valid = temp_valid;
                    // solvable = temp_valid;
                    // done = 1;
                    // Copy `grid` to `grid_out`.
                    
                    // Let's refine the Load mechanism.
                    // Since we have `row_idx` and `cell_idx`, we don't know when the user is "done" sending.
                    // We rely on the timer.
                    // So, in LOAD, we just latch whatever comes in.
                    // We need to ensure we capture row 0 if k=0 (default).
                    // If k>0, we assume user sends data.
                    
                end
                
                CHECK_INPUT: begin
                    // We use counter to distinguish cycles.
                    // Cycle 0: Check Row 0 uniqueness.
                    // Cycle 1: Check Row 1 == shift(Row 0) (if k > 1).
                    // Cycle 2: Check Row 2 == shift^2(Row 0) (if k > 2) AND Row 3 == shift^3(Row 0) (if k > 3).
                    // We need to perform checks and update temp_valid.
                    // Initialize temp_valid in IDLE or LOAD. Let's assume it starts high.
                    if (counter == 3'd0) begin
                        // Check Row 0 uniqueness
                        // Values are 2-bit. 1=00, 2=01, 3=10, 4=11.
                        // We need to check if all 4 values in row 0 are distinct.
                        // Simple check: sum of values == 6? No.
                        // XOR check? 00^01^10^11 = 00.
                        // But duplicates? 00^00^10^11 != 00.
                        // Actually, {a,b,c,d} is a permutation if a+b+c+d=6 AND distinct.
                        // Since values are 0..3 (shifted by -1), sum should be 0+1+2+3=6 (binary 110).
                        // Wait, mapping 1->00, 2->01, 3->10, 4->11 is 0,1,2,3.
                        // So sum should be 6.
                        // But sum is not unique proof. e.g. 0,0,3,3 sum=6.
                        // However, for a Latin square, we usually rely on distinctness.
                        // Let's use bit manipulation.
                        // If values are 0..3.
                        // We can check: 
                        // grid[0][0] != grid[0][1], etc.
                        // Or use a mask.
                        // If Row 0 is {A, B, C, D}, we check A!=B, A!=C, A!=D, B!=C, B!=D, C!=D.
                        // That's a lot of checks.
                        // We can use a 4-bit accumulator.
                        // `seen = 1 << grid[0][0] | 1 << grid[0][1] | ...`
                        // If `seen` == 1111 (15), it's unique.
                        // But we don't have a loop in combinational logic easily without blocking.
                        // Let's pre-calculate or simplify.
                        // Given the time constraints, let's assume the user inputs a valid row 0.
                        // But we must check.
                        // We can check in parallel.
                        // `temp_valid` stays high unless we find a mismatch.
                        // Let's do: 
                        // Check distinct pairs.
                        // Or, use a multi-bit comparator.
                        // Since we are in a clocked block, we can calculate this combinationally.
                        // `unique_0 = (grid[0][0] != grid[0][1] && grid[0][0] != grid[0][2] && ...)`
                        // Let's do that.
                        // We will update `temp_valid`.
                        // If `temp_valid` is currently 1 (initial state), we AND with new check.
                        // Note: `temp_valid` should be initialized to 1 before entering CHECK_INPUT.
                        // In IDLE, if start, temp_valid <= 1.
                        
                        // Checking uniqueness of Row 0:
                        // We need to ensure no duplicates.
                        // Let's write the condition.
                        if (grid[0][0] != grid[0][1] && grid[0][0] != grid[0][2] && grid[0][0] != grid[0][3] &&
                            grid[0][1] != grid[0][2] && grid[0][1] != grid[0][3] &&
                            grid[0][2] != grid[0][3]) begin
                            // Passed
                        end else begin
                            temp_valid <= 1'b0;
                        end
                    end else if (counter == 3'd1) begin
                        // Check Row 1
                        // Only if k > 1. 
                        // We need to compare grid[1][*] with shifted Row 0.
                        // Shifted Row 0: {grid[0][3], grid[0][0], grid[0][1], grid[0][2]}
                        if (k > 2'b01) begin // k > 1 means k >= 2 (since k is 2-bit)
                            // Actually k is 0,1,2,3. So k>=2 is k[1].
                            if (k >= 2) begin
                                if (grid[1][0] != grid[0][3] || grid[1][1] != grid[0][0] || grid[1][2] != grid[0][1] || grid[1][3] != grid[0][2]) begin
                                    temp_valid <= 1'b0;
                                end
                            end
                        end
                    end else if (counter == 3'd2) begin
                        // Check Row 2 (if k > 2) AND Row 3 (if k > 3)
                        // Row 2: {grid[0][2], grid[0][3], grid[0][0], grid[0][1]}
                        // Row 3: {grid[0][1], grid[0][2], grid[0][3], grid[0][0]}
                        if (k >= 3) begin
                            if (grid[2][0] != grid[0][2] || grid[2][1] != grid[0][3] || grid[2][2] != grid[0][0] || grid[2][3] != grid[0][1]) begin
                                temp_valid <= 1'b0;
                            end
                        end
                        if (k == 4) begin
                            if (grid[3][0] != grid[0][1] || grid[3][1] != grid[0][2] || grid[3][2] != grid[0][3] || grid[3][3] != grid[0][0]) begin
                                temp_valid <= 1'b0;
                            end
                        end
                    end
                    // Increment counter
                    counter <= counter + 1;
                end
                
                GENERATE: begin
                    // Generate rows 1, 2, 3 from row 0.
                    // We always generate rows 1, 2, 3.
                    // We write to grid.
                    // Counter 0: Row 1
                    // Counter 1: Row 2
                    // Counter 2: Row 3
                    if (counter == 3'd0) begin
                        grid[1][0] <= grid[0][3];
                        grid[1][1] <= grid[0][0];
                        grid[1][2] <= grid[0][1];
                        grid[1][3] <= grid[0][2];
                    end else if (counter == 3'd1) begin
                        grid[2][0] <= grid[0][2];
                        grid[2][1] <= grid[0][3];
                        grid[2][2] <= grid[0][0];
                        grid[2][3] <= grid[0][1];
                    end else if (counter == 3'd2) begin
                        grid[3][0] <= grid[0][1];
                        grid[3][1] <= grid[0][2];
                        grid[3][2] <= grid[0][3];
                        grid[3][3] <= grid[0][0];
                    end
                    counter <= counter + 1;
                end
                
                VERIFY: begin
                    // Verify columns.
                    // We need to check if each column contains {0,1,2,3} (mapped 1-4).
                    // We will use masks. 
                    // We need to reset masks before VERIFY starts.
                    // How to reset? 
                    // We can reset them in IDLE. Or handle them in VERIFY.
                    // Let's use `verify_mask_0` to `verify_mask_3`.
                    // We need to declare them as registers.
                    // We will update them every cycle.
                    // We have 2 cycles.
                    // We need to process all 4 rows.
                    // We can process 2 rows per cycle.
                    // Cycle 0 (counter 0): Rows 0 and 1.
                    // Cycle 1 (counter 1): Rows 2 and 3.
                    
                    if (counter == 3'd0) begin
                        // Reset masks first? 
                        // We can reset them in IDLE or START.
                        // Let's reset them in IDLE to 0.
                        // Then in VERIFY, we accumulate.
                        
                        // Process Row 0
                        // Col 0: grid[0][0]. Mask |= (1 << grid[0][0])
                        // But `grid` values are 0..3. `1 << value` works.
                        // But `grid` values are 2-bit. `1 << grid[0][0]` is 4 bit result?
                        // `1` is 32-bit. `1 << 2-bit` is fine.
                        
                        // Update masks based on Row 0 and Row 1
                        // We need to use non-blocking assignment for masks if we read and write them.
                        // But we are in sequential logic.
                        // We need to update the masks.
                        // We need to read previous mask state.
                        // We should have initialized masks to 0.
                        
                        // Row 0:
                        // Let's assume we use `reg [3:0] col_mask [0:3];`
                        // Initialize in IDLE: col_mask[0] <= 0; ...
                        
                        // Update logic for Row 0:
                        col_mask[0] <= col_mask[0] | (1'b1 << grid[0][0]);
                        col_mask[1] <= col_mask[1] | (1'b1 << grid[0][1]);
                        col_mask[2] <= col_mask[2] | (1'b1 << grid[0][2]);
                        col_mask[3] <= col_mask[3] | (1'b1 << grid[0][3]);
                        
                        // But wait, we need to update based on old values + new rows.
                        // In sequential logic, if we write back to col_mask, we use the value from previous cycle.
                        // We need to combine old and new.
                        // But `col_mask` will be updated.
                        // We need to handle the accumulation.
                        // `col_mask[i] <= col_mask[i] | ...`
                        // This works if `col_mask` holds the accumulated value from previous cycles.
                        // But we need to ensure `col_mask` is reset to 0 before VERIFY starts.
                        // We can reset them in IDLE.
                        
                    end else if (counter == 3'd1) begin
                        // Update masks based on Row 2 and Row 3
                        // But we need to use the values from Row 2 and 3.
                        // Wait, we didn't load `col_mask` with Row 0 and 1 yet?
                        // Yes, we did in counter 0.
                        // So now we OR in Row 2 and 3.
                        
                        // Row 2:
                        col_mask[0] <= col_mask[0] | (1'b1 << grid[2][0]);
                        col_mask[1] <= col_mask[1] | (1'b1 << grid[2][1]);
                        col_mask[2] <= col_mask[2] | (1'b1 << grid[2][2]);
                        col_mask[3] <= col_mask[3] | (1'b1 << grid[2][3]);
                        
                        // Row 3:
                        // Wait, we can't update col_mask twice in one block easily with non-blocking.
                        // We need to combine Row 2 and 3 updates.
                        // Or use intermediate values.
                        // Let's use a combinational block for the update logic or calculate the result.
                        // Since we are inside always @(posedge clk), we can do:
                        
                        // col_mask[0] <= col_mask[0] | (1 << grid[0][0]) | (1 << grid[2][0]) ... 
                        // But we only know Row 0 update happened in previous cycle.
                        // The `col_mask` register now contains the mask with Row 0 and Row 1.
                        // So we just OR Row 2 and 3.
                        // But we need to include Row 1? We did Row 0 in cycle 0.
                        // Wait, we only processed Row 0 in cycle 0.
                        // We need to process Row 1 as well.
                        // So in cycle 0, we need to process Row 0 AND Row 1.
                        // In cycle 1, Row 2 AND Row 3.
                        
                        // Revisiting Cycle 0:
                        // We need to update masks with Row 0 and Row 1.
                        // We can do this in one go.
                        // `col_mask[0] <= col_mask[0] | (1 << grid[0][0]) | (1 << grid[1][0]);`
                        // Yes.
                        
                        // Revisiting Cycle 1:
                        // `col_mask[0] <= col_mask[0] | (1 << grid[2][0]) | (1 << grid[3][0]);`
                        
                        // At the end of Cycle 1, we check if all col_mask == 1111.
                        // But we need to do this check at the end of VERIFY state.
                        // We can check inside the cycle and set `temp_valid`.
                        
                        // Cycle 0:
                        if (counter == 3'd0) begin
                            col_mask[0] <= (1'b1 << grid[0][0]) | (1'b1 << grid[1][0]);
                            col_mask[1] <= (1'b1 << grid[0][1]) | (1'b1 << grid[1][1]);
                            col_mask[2] <= (1'b1 << grid[0][2]) | (1'b1 << grid[1][2]);
                            col_mask[3] <= (1'b1 << grid[0][3]) | (1'b1 << grid[1][3]);
                        end
                        // Cycle 1:
                        if (counter == 3'd1) begin
                            col_mask[0] <= col_mask[0] | (1'b1 << grid[2][0]) | (1'b1 << grid[3][0]);
                            col_mask[1] <= col_mask[1] | (1'b1 << grid[2][1]) | (1'b1 << grid[3][1]);
                            col_mask[2] <= col_mask[2] | (1'b1 << grid[2][2]) | (1'b1 << grid[3][2]);
                            col_mask[3] <= col_mask[3] | (1'b1 << grid[2][3]) | (1'b1 << grid[3][3]);
                            
                            // Check validity
                            // If all masks are 1111 (4'b1111 = 4'hF)
                            // We can check here.
                            // But we need to update `temp_valid`.
                            if ((col_mask[0] | (1'b1 << grid[2][0]) | (1'b1 << grid[3][0])) == 4'b1111 &&
                                (col_mask[1] | (1'b1 << grid[2][1]) | (1'b1 << grid[3][1])) == 4'b1111 &&
                                (col_mask[2] | (1'b1 << grid[2][2]) | (1'b1 << grid[3][2])) == 4'b1111 &&
                                (col_mask[3] | (1'b1 << grid[2][3]) | (1'b1 << grid[3][3])) == 4'b1111) begin
                                // Wait, `col_mask` here is the OLD value (before update).
                                // So I need to compute the new value.
                                // Or just rely on the fact that `col_mask` will be updated.
                                // But I need to update `temp_valid` now.
                                
                                // Let's compute the final masks combinationally for the check.
                                // `temp_mask_0 = col_mask[0] | (1 << grid[2][0]) | (1 << grid[3][0])`
                                // And check.
                                
                                // Or simpler: Just check at the end of the state.
                                // Since this is the last cycle of VERIFY.
                                // We can check `temp_mask` values.
                                // But `col_mask` hasn't been updated yet (non-blocking).
                                // So I can't rely on `col_mask` in this block for the *new* value.
                                // I must calculate it explicitly or move check to combinational logic.
                                // Or use blocking assignment for the check.
                                // Or check inside combinational logic for next_state.
                                
                                // Let's use a combinational block for `temp_valid` updates? 
                                // No, we need to set `valid` output.
                                // We will perform the check in DONE state using the final masks.
                                // Or perform the check here using intermediate values.
                                
                                // Intermediate values:
                                // Let's assume we calculate `final_mask_0` etc.
                                // But we are inside the sequential block.
                                // Let's do: 
                                // Update masks (non-blocking).
                                // And set a flag `verify_check_pass` (blocking) based on the check.
                                // And then update `temp_valid`.
                                // Wait, `temp_valid` is a register.
                                // We can do: `if (check_condition) temp_valid <= temp_valid & 1; else temp_valid <= 0;`
                                
                                // Let's just verify the final condition.
                                // We have `col_mask` (from previous cycle, i.e., Row 0+1).
                                // We add Row 2+3.
                                // We need to see if the OR result is 1111.
                                // Let's calculate the `new_mask_0`.
                                // `new_mask_0 = col_mask[0] | (1 << grid[2][0]) | (1 << grid[3][0]);`
                                // `new_mask_0 == 15`.
                                
                                // We can't easily do this for all 4 columns in one line without temporary wires.
                                // Let's define temporary wires at the top of the module? 
                                // No, I should keep it in the module body.
                                // Let's define the logic inside the block.
                                
                                // We will update `temp_valid` only in the last cycle (counter 1).
                                // We need to check if the masks become 1111.
                                // Since we are in clocked block, we can't see the new `col_mask` value.
                                // So we must compute the "next" value.
                                
                                // Let's do this:
                                // `temp_valid <= temp_valid & (
                                //     ((col_mask[0] | (1<<grid[2][0]) | (1<<grid[3][0])) == 15) &&
                                //     ...
                                // );`
                                // This works.
                                
                                temp_valid <= temp_valid & (
                                    ((col_mask[0] | (1'b1 << grid[2][0]) | (1'b1 << grid[3][0])) == 4'b1111) &&
                                    ((col_mask[1] | (1'b1 << grid[2][1]) | (1'b1 << grid[3][1])) == 4'b1111) &&
                                    ((col_mask[2] | (1'b1 << grid[2][2]) | (1'b1 << grid[3][2])) == 4'b1111) &&
                                    ((col_mask[3] | (1'b1 << grid[2][3]) | (1'b1 << grid[3][3])) == 4'b1111)
                                );
                            end
                        end
                        
                        // Increment counter
                        counter <= counter + 1;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    valid <= temp_valid;
                    solvable <= temp_valid;
                    // Copy grid to grid_out
                    // This is a combinational output usually, but we can latch it.
                    // Since grid_out is output reg, we assign it here.
                    grid_out[0][0] <= grid[0][0]; grid_out[0][1] <= grid[0][1]; grid_out[0][2] <= grid[0][2]; grid_out[0][3] <= grid[0][3];
                    grid_out[1][0] <= grid[1][0]; grid_out[1][1] <= grid[1][1]; grid_out[1][2] <= grid[1][2]; grid_out[1][3] <= grid[1][3];
                    grid_out[2][0] <= grid[2][0]; grid_out[2][1] <= grid[2][1]; grid_out[2][2] <= grid[2][2]; grid_out[2][3] <= grid[2][3];
                    grid_out[3][0] <= grid[3][0]; grid_out[3][1] <= grid[3][1]; grid_out[3][2] <= grid[3][2]; grid_out[3][3] <= grid[3][3];
                end
            endcase
        end
    end
    
    // Extra logic for LOAD state to handle the "start" signal and inputs
    // We need to handle the loading of inputs correctly.
    // The previous block handles state transitions.
    // We need to handle data latching.
    // The LOAD state logic in the main always block needs to latch data.
    // Let's add a separate combinational or sequential block for latching data in LOAD.
    // Actually, we can do it in the main block.
    // But we need to be careful about `grid` updates.
    // We can separate the datapath updates.
    
    // Let's refine the LOAD section in the main FSM:
    // We need to latch data_in into grid[row_idx][cell_idx].
    // This should happen whenever we are in LOAD state.
    // Since `grid` is a register, we can do:
    // if (state == LOAD) grid[row_idx][cell_idx] <= data_in;
    // But this might conflict if we update `grid` in other states.
    // In GENERATE, we update `grid`.
    // In CHECK_INPUT, we read `grid`.
    // So we can add this as a separate condition.
    // However, we need to make sure we only load `k` rows? 
    // Or just let the user fill it?
    // We will rely on the user providing inputs for the first `k` rows.
    // And we will stay in LOAD for 4 cycles (as per state machine counter).
    // 
    // Let's add a sequential block for loading:
    // This block runs when state is LOAD.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic handled in main block
        end else begin
            if (state == LOAD) begin
                // We assume the inputs row_idx, cell_idx, data_in are valid.
                // We update the grid.
                grid[row_idx][cell_idx] <= data_in;
            end
        end
    end
    
    // Also, we need to handle the transition out of LOAD.
    // We need to know when to stop loading.
    // The state machine uses a counter for LOAD state.
    // We need to increment `counter` in LOAD state.
    // In the main FSM block, we didn't handle counter increment for LOAD.
    // We only handled CHECK_INPUT and GENERATE.
    // Let's fix that.
    
    // Revised LOAD logic in main FSM:
    // In IDLE: if start, counter <= 0.
    // In LOAD: counter <= counter + 1. (Wait, LOAD duration is 4 cycles).
    // If counter reaches 3 (0,1,2,3), next state is CHECK_INPUT.
    
    // But wait, we need to ensure `temp_valid` is initialized.
    // In IDLE: if start, temp_valid <= 1.
    
    // What about `k` check?
    // If k=0, we skip LOAD. 
    // If k=0, we go directly to GENERATE.
    // In GENERATE, we generate rows 1,2,3.
    // But we need Row 0.
    // If k=0, we need a default Row 0.
    // The prompt says: "Row 0: as given (or default 1,2,3,4 if k=0)"
    // So in IDLE, if k=0, we set grid[0] to default.
    
    // Let's update the main FSM block with these details.
    
    // Combined Logic Check:
    // 1. IDLE: 
    //    - Wait for start.
    //    - If start: reset counters, set temp_valid=1, done=0, valid=0.
    //    - If start AND k==0: set default Row 0. Next state = GENERATE.
    //    - If start AND k>0: Next state = LOAD.
    // 2. LOAD:
    //    - Latch inputs.
    //    - Increment counter.
    //    - When counter == 4, Next state = CHECK_INPUT.
    //    - Note: We need to make sure we don't miss inputs. 
    //    - Since we stay 4 cycles, user has 4 cycles to send inputs.
    //    - If k=1, user sends inputs for 4 cycles (maybe repeating or filling). We accept all.
    //    - If k=4, user sends inputs. We accept all. 
    //    - This seems okay. We load whatever is sent.
    // 3. CHECK_INPUT:
    //    - Counter 0: Check Row 0 unique. (Update temp_valid).
    //    - Counter 1: Check Row 1 match. (Update temp_valid).
    //    - Counter 2: Check Row 2 & 3 match. (Update temp_valid).
    //    - When counter == 3, Next state = GENERATE.
    // 4. GENERATE:
    //    - Counter 0: Gen Row 1.
    //    - Counter 1: Gen Row 2.
    //    - Counter 2: Gen Row 3.
    //    - When counter == 3, Next state = VERIFY.
    // 5. VERIFY:
    //    - Counter 0: Update masks (Rows 0, 1).
    //    - Counter 1: Update masks (Rows 2, 3) and check result.
    //    - When counter == 2, Next state = DONE.
    // 6. DONE:
    //    - Set outputs.
    
    // We need to implement the counter increment and state transition logic carefully.
    
    // Let's rewrite the `always @(posedge clk ...)` block completely to ensure cohesion.
    // I will merge the logic into one block for clarity and to avoid dependency issues.
    
    // We need `col_mask` registers for VERIFY.
    reg [3:0] col_mask_0, col_mask_1, col_mask_2, col_mask_3;
    
    // We need to manage the `counter` correctly.
    // In IDLE, counter is 0.
    // In LOAD, counter increments 0 to 3 (4 cycles).
    // In CHECK_INPUT, counter increments 0 to 2 (3 cycles).
    // In GENERATE, counter increments 0 to 2 (3 cycles).
    // In VERIFY, counter increments 0 to 1 (2 cycles).
    
    // Let's update the main always block.
    
    // We need to reset the block properly.
    // I will overwrite the previous logic with a clean, integrated version.

    // Integrated FSM and Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            solvable <= 1'b0;
            done <= 1'b0;
            temp_valid <= 1'b0;
            counter <= 3'd0;
            col_mask_0 <= 4'b0;
            col_mask_1 <= 4'b0;
            col_mask_2 <= 4'b0;
            col_mask_3 <= 4'b0;
            // Clear grid_out
            integer i, j;
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 4; j = j + 1) begin
                    grid_out[i][j] <= 2'b0;
                    grid[i][j] <= 2'b0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        done <= 1'b0;
                        valid <= 1'b0;
                        solvable <= 1'b0;
                        temp_valid <= 1'b1; // Optimistic
                        counter <= 3'd0;
                        
                        // Initialize col masks to 0 for VERIFY
                        col_mask_0 <= 4'b0;
                        col_mask_1 <= 4'b0;
                        col_mask_2 <= 4'b0;
                        col_mask_3 <= 4'b0;
                        
                        if (k == 2'b00) begin
                            // Default Row 0
                            grid[0][0] <= 2'b00; // 1
                            grid[0][1] <= 2'b01; // 2
                            grid[0][2] <= 2'b10; // 3
                            grid[0][3] <= 2'b11; // 4
                            state <= GENERATE;
                        end else begin
                            state <= LOAD;
                        end
                    end
                end
                
                LOAD: begin
                    // Latch input
                    grid[row_idx][cell_idx] <= data_in;
                    
                    // Increment counter
                    if (counter < 3'd4) begin
                        counter <= counter + 1;
                    end
                    
                    // Transition
                    if (counter == 3'd3) begin // 4 cycles done (0,1,2,3)
                        state <= CHECK_INPUT;
                        counter <= 3'd0; // Reset for next state
                    end
                end
                
                CHECK_INPUT: begin
                    // We perform checks and update temp_valid
                    // Counter determines which check
                    if (counter == 3'd0) begin
                        // Check Row 0 uniqueness
                        // 6 comparisons
                        if (!(grid[0][0] != grid[0][1] && grid[0][0] != grid[0][2] && grid[0][0] != grid[0][3] &&
                              grid[0][1] != grid[0][2] && grid[0][1] != grid[0][3] &&
                              grid[0][2] != grid[0][3])) begin
                            temp_valid <= 1'b0;
                        end
                        counter <= 1;
                    end else if (counter == 3'd1) begin
                        // Check Row 1 if k >= 2
                        if (k >= 2) begin
                            if (grid[1][0] != grid[0][3] || grid[1][1] != grid[0][0] || grid[1][2] != grid[0][1] || grid[1][3] != grid[0][2]) begin
                                temp_valid <= 1'b0;
                            end
                        end
                        counter <= 2;
                    end else if (counter == 3'd2) begin
                        // Check Row 2 if k >= 3
                        if (k >= 3) begin
                            if (grid[2][0] != grid[0][2] || grid[2][1] != grid[0][3] || grid[2][2] != grid[0][0] || grid[2][3] != grid[0][1]) begin
                                temp_valid <= 1'b0;
                            end
                        end
                        // Check Row 3 if k == 4
                        if (k == 4) begin
                            if (grid[3][0] != grid[0][1] || grid[3][1] != grid[0][2] || grid[3][2] != grid[0][3] || grid[3][3] != grid[0][0]) begin
                                temp_valid <= 1'b0;
                            end
                        end
                        state <= GENERATE;
                        counter <= 3'd0;
                    end
                end
                
                GENERATE: begin
                    // Generate rows 1, 2, 3 from Row 0
                    // Always generate all 3 rows (overwriting if k>1, etc, but we checked them)
                    // Actually, if k>1, Row 1 is already loaded. Should we overwrite?
                    // The algorithm says "Generate remaining rows".
                    // If k=2, Row 1 is given. We shouldn't overwrite it because we verified it.
                    // If we overwrite, we might change a valid row.
                    // BUT, if temp_valid is false (mismatch), we might overwrite.
                    // Actually, we should generate the rows regardless of k to fill the grid.
                    // If k=2, we generate Row 2 and Row 3. Row 0 and 1 are already there.
                    // Wait, Row 1 is given. We verified it matches shift(Row 0).
                    // We can generate Row 1 again (it will be same).
                    // Let's generate rows 1, 2, 3.
                    // But we need to be careful about which rows to generate.
                    // We should generate rows that are NOT given?
                    // "Generate remaining rows".
                    // So if k=2, generate rows 2 and 3.
                    // But we have a 3-cycle GENERATE state (Counter 0, 1, 2).
                    // This fits perfectly: Row 1, Row 2, Row 3.
                    // If k=2, we only need to generate Row 2 and 3.
                    // But our state is generic.
                    // Let's generate Row 1, 2, 3.
                    // If k=2, Row 1 is already there. We overwrite it. 
                    // Is that bad? No, we verified it matches. So overwriting with correct value is fine.
                    // If k=4, we overwrite all. That's fine too.
                    
                    // Cycle 0: Generate Row 1
                    grid[1][0] <= grid[0][3];
                    grid[1][1] <= grid[0][0];
                    grid[1][2] <= grid[0][1];
                    grid[1][3] <= grid[0][2];
                    
                    // Cycle 1: Generate Row 2
                    if (counter == 3'd1) begin
                        grid[2][0] <= grid[0][2];
                        grid[2][1] <= grid[0][3];
                        grid[2][2] <= grid[0][0];
                        grid[2][3] <= grid[0][1];
                    end
                    
                    // Cycle 2: Generate Row 3
                    if (counter == 3'd2) begin
                        grid[3][0] <= grid[0][1];
                        grid[3][1] <= grid[0][2];
                        grid[3][2] <= grid[0][3];
                        grid[3][3] <= grid[0][0];
                    end
                    
                    if (counter < 3'd2) begin
                        counter <= counter + 1;
                    end else begin
                        state <= VERIFY;
                        counter <= 3'd0;
                    end
                end
                
                VERIFY: begin
                    // Verify columns
                    // Cycle 0: Process Rows 0 and 1, initialize masks
                    // Cycle 1: Process Rows 2 and 3, check results
                    
                    if (counter == 3'd0) begin
                        // Initialize masks with Row 0 and 1
                        col_mask_0 <= (1'b1 << grid[0][0]) | (1'b1 << grid[1][0]);
                        col_mask_1 <= (1'b1 << grid[0][1]) | (1'b1 << grid[1][1]);
                        col_mask_2 <= (1'b1 << grid[0][2]) | (1'b1 << grid[1][2]);
                        col_mask_3 <= (1'b1 << grid[0][3]) | (1'b1 << grid[1][3]);
                        
                        counter <= 1;
                    end else if (counter == 3'd1) begin
                        // Update with Rows 2 and 3
                        // Check if valid
                        // We need to check if the final mask is 1111.
                        // We can compute the update and check.
                        // `new_mask_0 = col_mask_0 | (1<<grid[2][0]) | (1<<grid[3][0])`
                        
                        if ( (col_mask_0 | (1'b1 << grid[2][0]) | (1'b1 << grid[3][0])) == 4'b1111 &&
                             (col_mask_1 | (1'b1 << grid[2][1]) | (1'b1 << grid[3][1])) == 4'b1111 &&
                             (col_mask_2 | (1'b1 << grid[2][2]) | (1'b1 << grid[3][2])) == 4'b1111 &&
                             (col_mask_3 | (1'b1 << grid[2][3]) | (1'b1 << grid[3][3])) == 4'b1111 ) begin
                            // Pass
                        end else begin
                            temp_valid <= 1'b0;
                        end
                        
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    // Update outputs
                    done <= 1'b1;
                    valid <= temp_valid;
                    solvable <= temp_valid;
                    
                    // Copy grid to grid_out
                    // We can do this continuously or just once.
                    // Since it's a reg output, we assign once.
                    // We can assign here.
                    grid_out[0][0] <= grid[0][0]; grid_out[0][1] <= grid[0][1]; grid_out[0][2] <= grid[0][2]; grid_out[0][3] <= grid[0][3];
                    grid_out[1][0] <= grid[1][0]; grid_out[1][1] <= grid[1][1]; grid_out[1][2] <= grid[1][2]; grid_out[1][3] <= grid[1][3];
                    grid_out[2][0] <= grid[2][0]; grid_out[2][1] <= grid[2][1]; grid_out[2][2] <= grid[2][2]; grid_out[2][3] <= grid[2][3];
                    grid_out[3][0] <= grid[3][0]; grid_out[3][1] <= grid[3][1]; grid_out[3][2] <= grid[3][2]; grid_out[3][3] <= grid[3][3];
                end
            endcase
        end
    end

endmodule
