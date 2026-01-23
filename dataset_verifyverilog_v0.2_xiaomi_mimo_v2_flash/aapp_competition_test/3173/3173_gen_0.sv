module top (
    input clk,
    input rst_n,
    input start,
    input [5:0] R,  // max 50
    input [5:0] C,  // max 50
    input [31:0] K, // number of parts
    input [7:0] grid_row [0:49], // flattened grid rows, one row at a time
    input [31:0] score [0:49],   // scores at bottom row
    output reg [63:0] result,
    output reg done
);

    // Internal signals for the datapath and control
    wire [31:0] gain_current;
    wire dp_valid;
    wire [5:0] col_idx_out;
    wire dp_done;
    wire part_done;
    
    // State encoding
    localparam IDLE = 3'd0;
    localparam LOAD_GRID = 3'd1;
    localparam SIMULATE_PART = 3'd2;
    localparam CHECK_CYCLE = 3'd3;
    localparam COMPUTE_FINAL = 3'd4;
    localparam FINISHED = 3'd5;

    reg [2:0] state;
    
    // Simulation counters
    reg [5:0] current_part;
    reg [31:0] total_score_low;
    reg [31:0] total_score_high;
    
    // Cycle detection storage (History of gains: depth 64)
    reg [31:0] gain_history [0:63];
    reg [5:0] history_ptr;
    reg [5:0] cycle_start;
    reg [5:0] cycle_len;
    reg cycle_found;
    
    // Grid loading state
    reg [5:0] row_ptr;
    reg [5:0] col_ptr;
    reg grid_loaded;
    
    // Module Instantiation
    part_simulator dp_unit (
        .clk(clk),
        .rst_n(rst_n),
        .R(R),
        .C(C),
        .start_dp((state == LOAD_GRID && grid_loaded) || (state == SIMULATE_PART && part_done)),
        .grid_row(grid_row),
        .grid_row_valid((state == LOAD_GRID)),
        .score(score),
        .col_idx_in(history_ptr), // Used to map start columns
        .gain_out(gain_current),
        .valid_out(dp_valid),
        .done(dp_done)
    );

    // Control Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            current_part <= 0;
            total_score_low <= 0;
            total_score_high <= 0;
            history_ptr <= 0;
            cycle_found <= 0;
            row_ptr <= 0;
            grid_loaded <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD_GRID;
                        row_ptr <= 0;
                        grid_loaded <= 0;
                        history_ptr <= 0;
                        current_part <= 0;
                        total_score_low <= 0;
                        total_score_high <= 0;
                        cycle_found <= 0;
                        done <= 0;
                    end
                end

                LOAD_GRID: begin
                    // Assuming grid is provided over multiple cycles or fully available
                    // Here we wait for DP unit to process the grid
                    // If we treat grid_row as valid input per cycle, we might stream it.
                    // For this interface, we assume grid_row is static or ready.
                    // We trigger the DP calculation once.
                    // Wait for dp_done to indicate grid processing finished for part 0 start
                    if (dp_done) begin
                        state <= SIMULATE_PART;
                        grid_loaded <= 1;
                        history_ptr <= 0; // Reset ptr to record start columns
                        current_part <= 0;
                    end
                end

                SIMULATE_PART: begin
                    // We need to simulate K parts or until cycle found.
                    // The DP unit iterates through all columns.
                    // We use history_ptr to track which column we are simulating for the current part.
                    // Wait for dp_valid to get gain for current column.
                    // Accumulate score.
                    // Since K can be large, we simulate part by part.
                    // Wait for part simulation to complete (all columns).
                    
                    // Since the prompt requires simulation logic inside top, we refine the flow:
                    // The `part_simulator` must run R times (rows) for each column.
                    // Let's assume `part_simulator` does the heavy lifting.
                    
                    // Let's treat `part_simulator` as a block that computes gain for a specific start column.
                    // We iterate start columns 0 to C-1.
                    // We accumulate gain into result.
                    
                    // Wait for dp_valid from part_simulator
                    if (dp_valid) begin
                        // Add gain to total score
                        {total_score_high, total_score_low} <= {total_score_high, total_score_low} + gain_current;
                    end
                    
                    if (part_done) begin
                        // One part simulation complete for all columns (or just the ones we needed)
                        // Actually, for the problem "Find maximum score after K parts", 
                        // we usually map Input Col -> Output Score.
                        // Then Input Col = Argmax of Previous Output Score.
                        // Cycle detection is on the Gain function: Gain(Col) -> NextCol.
                        
                        // Let's rethink the `part_simulator` interface in the context of the `top` FSM.
                        // `part_simulator` should compute the whole Gain table [0...C-1] in one shot.
                        // Or iterate columns internally.
                        
                        // Assuming `part_simulator` iterates columns internally:
                        // Wait for `part_done`.
                        
                        // Update Cycle Detection Logic here (simplified)
                        // Since K is large, we look for periodicity in the *best column sequence*.
                        // However, the problem asks for max score, which might be sum of gains.
                        
                        // Let's assume `part_simulator` outputs `max_score_out` for the best start column.
                        // Or we need to run `part_simulator` for every column.
                        // Given the interface `col_idx_in`, we likely drive it.
                        
                        // Cycle detection logic:
                        // Record the column that yields max score (assuming we pick max from previous part).
                        // Since we can't easily do that without full history, we store the Gain Vector (size C).
                        // But C <= 50, so we can store it.
                        
                        current_part <= current_part + 1;
                        if (current_part == K - 1 || cycle_found) begin
                            state <= COMPUTE_FINAL;
                        end
                    end
                end

                COMPUTE_FINAL: begin
                    // Calculate final result using cycle parameters
                    if (cycle_found) begin
                        // Result = (Pre-cycle sum) + (Number of cycles * Cycle sum) + (Remaining sum)
                        // result <= ...;
                    end else begin
                        result <= {total_score_high, total_score_low};
                    end
                    state <= FINISHED;
                end

                FINISHED: begin
                    done <= 1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end

endmodule

module part_simulator (
    input clk,
    input rst_n,
    input [5:0] R,
    input [5:0] C,
    input start_dp,
    input [7:0] grid_row [0:49], // Flattened or packed input
    input grid_row_valid,
    input [31:0] score [0:49],
    input [5:0] col_idx_in, // Starting column index to simulate
    output reg [31:0] gain_out,
    output reg valid_out,
    output reg done
);

    // Internal memory for DP state
    // DP[r][c] stores max score from row r, col c to bottom.
    // Since R <= 50 and C <= 50, we can use registers or BRAM.
    // Using 2D array logic [50][50] is feasible in synthesis.
    // However, grid size is 50x50 = 2500 cells. 
    // Storing [50][50] * 32 bits = 80k bits. That's okay for registers in large FPGAs, 
    // but let's optimize to use BRAM or streaming if possible.
    // However, we need random access for conveyors (L/R).
    // Let's store the full grid first. We need 2500 * 8 bits = 20kbits for grid.
    
    reg [7:0] grid_mem [0:49][0:49]; // 50x50 grid memory
    reg [31:0] dp [0:49][0:49];      // DP memory for current part
    
    // Control State
    localparam IDLE = 3'd0;
    localparam LOAD_GRID = 3'd1;
    localparam CALC_BOTTOM = 3'd2;
    localparam CALC_UP = 3'd3;
    localparam OUTPUT_RESULT = 3'd4;
    
    reg [2:0] state;
    reg [5:0] r_reg; // Row pointer
    reg [5:0] c_reg; // Col pointer
    reg [5:0] load_row_ptr;
    
    // Grid loading logic
    // Note: The interface `grid_row` is a 50 element array of 8-bit values.
    // This implies one row is transferred per cycle.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            valid_out <= 0;
            load_row_ptr <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    valid_out <= 0;
                    if (start_dp) begin
                        state <= LOAD_GRID;
                        load_row_ptr <= 0;
                    end
                end

                LOAD_GRID: begin
                    // In reality, `grid_row` might be static on input, or streamed.
                    // If streamed: `grid_row` changes per cycle. 
                    // We need to store the row provided.
                    // The prompt says `input [7:0] grid_row [0:49]`. 
                    // This is an array input. In Verilog/SV, this is tricky for top-level ports unless flattened.
                    // Let's assume `grid_row` is the current row data when `grid_row_valid` is high.
                    // Wait, the prompt says "flattened grid rows, one row at a time".
                    // This means we iterate `load_row_ptr` from 0 to R-1.
                    // We need to write `grid_row` into `grid_mem[load_row_ptr]`.
                    // Since `grid_row` is an array, we can assign it directly.
                    // We need a handshake or counter. Let's assume we consume `grid_row_valid`.
                    
                    // Since `grid_row` is not a valid signal but a bus, we might need to know which row it is.
                    // OR, simpler: The testbench provides `grid_row` as a static array of all rows? 
                    // "flattened grid rows, one row at a time" suggests streaming.
                    // Let's assume `grid_row` represents the row at index `load_row_ptr`.
                    // We just need to copy it.
                    
                    for (int i = 0; i < 50; i++) begin
                        // Only copy up to C columns to be safe, but memory is 50 wide.
                        // We assume input provides 50 elements always.
                        if (i < C) grid_mem[load_row_ptr][i] <= grid_row[i];
                        else grid_mem[load_row_ptr][i] <= 8'h0;
                    end
                    
                    if (load_row_ptr == R - 1) begin
                        state <= CALC_BOTTOM;
                        load_row_ptr <= 0;
                        c_reg <= 0;
                    end else begin
                        load_row_ptr <= load_row_ptr + 1;
                    end
                end

                CALC_BOTTOM: begin
                    // Initialize DP[R][c] = score[c]
                    // Note: DP array is 0..49. We map row R (1-based) to index R-1 or just use index R.
                    // Let's use index r (0 to R). So DP array size needs to be [51][50].
                    // Or we can use [50][50] and map row R to index R-1.
                    // Let's allocate DP[50][50]. 
                    // Row R (the bottom row, 1-based) -> index R-1.
                    // Row 1 -> index 0.
                    // Wait, the description says DP[R][c]. R is height.
                    // If R=10, rows are 0..9. Bottom row is 9.
                    // Let's assume DP table stores values for the current row.
                    // We calculate from bottom (row R-1) to top (row 0).
                    
                    if (c_reg < C) begin
                        dp[R-1][c_reg] <= score[c_reg];
                        c_reg <= c_reg + 1;
                    end else begin
                        state <= CALC_UP;
                        r_reg <= R - 2; // Start from row R-2
                        c_reg <= 0;
                    end
                end

                CALC_UP: begin
                    // Calculate dp[r][c] based on dp[r+1][...]
                    if (c_reg < C) begin
                        // Logic for current cell
                        case (grid_mem[r_reg][c_reg])
                            8'h2E: begin // '.' (Empty)
                                dp[r_reg][c_reg] <= dp[r_reg+1][c_reg];
                            end
                            8'h58: begin // 'X' (Obstacle)
                                dp[r_reg][c_reg] <= 0; // Or -inf. 0 seems safe for non-negative scores.
                            end
                            8'h4C: begin // 'L' (Left)
                                if (c_reg > 0) dp[r_reg][c_reg] <= dp[r_reg+1][c_reg-1];
                                else dp[r_reg][c_reg] <= 0;
                            end
                            8'h52: begin // 'R' (Right)
                                if (c_reg < C - 1) dp[r_reg][c_reg] <= dp[r_reg+1][c_reg+1];
                                else dp[r_reg][c_reg] <= 0;
                            end
                            8'h3F: begin // '?' (Optimize)
                                // dp[r][c] = max(dp[r+1][c-1], dp[r+1][c+1])
                                // Handle boundary cases
                                // If one is invalid, take the other.
                                // If both invalid, 0.
                                // Note: The problem says "The robot can choose... to maximize its final score".
                                // We want max score.
                                
                                // Left value
                                wire [31:0] val_l = (c_reg > 0) ? dp[r_reg+1][c_reg-1] : 0;
                                // Right value
                                wire [31:0] val_r = (c_reg < C - 1) ? dp[r_reg+1][c_reg+1] : 0;
                                
                                dp[r_reg][c_reg] <= (val_l > val_r) ? val_l : val_r;
                            end
                            default: dp[r_reg][c_reg] <= dp[r_reg+1][c_reg];
                        endcase
                        
                        c_reg <= c_reg + 1;
                    end else begin
                        if (r_reg == 0) begin
                            state <= OUTPUT_RESULT;
                            c_reg <= 0;
                        end else begin
                            r_reg <= r_reg - 1;
                            c_reg <= 0;
                        end
                    end
                end

                OUTPUT_RESULT: begin
                    // We need to output the gain for `col_idx_in`.
                    // The gain is dp[0][col_idx_in].
                    // Wait, the `part_simulator` is instantiated in `top`. 
                    // The `top` FSM needs to iterate through all columns to build the Gain Vector.
                    // Or `part_simulator` iterates through columns and outputs a stream.
                    // The `top` interface `col_idx_in` suggests `top` requests a specific column.
                    // But `part_simulator` calculates the whole table.
                    
                    // Let's assume `part_simulator` iterates through all columns and outputs them sequentially.
                    // Or `top` feeds `col_idx_in` 0..C-1 and we output one by one.
                    // The prompt says "max_score_out" (singular).
                    // So `top` probably sets `col_idx_in`, triggers `start_dp`, waits for `valid_out`.
                    // But `start_dp` triggers the whole grid load and calc.
                    
                    // Optimization: `part_simulator` computes the whole table. 
                    // Then `top` can read results for different columns.
                    // However, `part_simulator` has `col_idx_in`. 
                    // Let's change `OUTPUT_RESULT` to present the value at `dp[0][col_idx_in]`.
                    
                    gain_out <= dp[0][col_idx_in];
                    valid_out <= 1'b1;
                    done <= 1'b1;
                    state <= IDLE; // Back to idle to wait for next request (if any)
                    // Note: If `top` needs all columns, it might re-trigger `start_dp` or 
                    // `part_simulator` should iterate `col_idx_in` internally.
                    // Given `top` has complex logic, let's assume `part_simulator` computes everything once.
                    // To fit the interface, `part_simulator` will output `valid_out` when done.
                    // The `top` will then read `gain_out` for the current `col_idx_in`.
                    // Wait, `part_simulator` must know `col_idx_in` *before* calculation to return the right one?
                    // No, it calculates the whole table.
                    // `top` will likely run `part_simulator` once, then iterate `col_idx_in` to read values.
                    // BUT `part_simulator` is a state machine. It runs once.
                    
                    // Let's make `part_simulator` return the MAX score of the current row (DP[0][*]) or specific.
                    // Actually, let's implement `part_simulator` to output the Gain for `col_idx_in`.
                    // But we need to calculate the whole DP table to get that value.
                    // So we do CALC_UP, then set `gain_out` and `valid_out`.
                    
                    // However, `top` needs to compute K parts. 
                    // For each part, `top` needs the mapping: Col -> Gain.
                    // Since C <= 50, `top` can call `part_simulator` 50 times (updating `col_idx_in`) or 
                    // `part_simulator` can output a vector.
                    // Given the signals, let's assume `part_simulator` calculates the whole table and outputs `gain_out` for `col_idx_in`.
                    // `top` sets `col_idx_in` to 0, triggers. Gets gain. Sets to 1, triggers. etc.
                    // That's slow (50 cycles per part).
                    // Or `part_simulator` runs once and outputs `valid_out` when the whole table is ready.
                    // Then `top` can just read `dp[0][x]` by addressing. 
                    // But `part_simulator` only exposes `gain_out` (32 bit).
                    // So `part_simulator` must iterate columns internally if we want efficiency.
                    // Let's go with `top` driving `col_idx_in` and `part_simulator` computing just that column.
                    // BUT, to compute `dp[0][c]`, we need `dp[1][...]`, which needs `dp[2][...]`.
                    // We don't need the whole table, just the dependencies.
                    // For a specific `col_idx_in`, we only need the columns reachable from it.
                    // Reachable columns at row r from col `c` at row 0 are within `c-r` to `c+r`.
                    // So we can compute a window.
                    
                    // Let's implement `part_simulator` to compute the gain for `col_idx_in` using a 1D DP array of width C.
                    // We fill it from bottom to top.
                    // This avoids storing the whole grid (though we need grid access).
                    // To support `?` (max of neighbors), we need neighbors.
                    // So we need a window.
                    // Let's allocate `dp_buffer[0...R]` of width C.
                    // This is still R*C = 2500 entries.
                    // Let's stick to the full table approach for simplicity and robustness against random access.
                    // But we can optimize it.
                    
                    // REVISION: Let's make `part_simulator` compute the gain for `col_idx_in` only.
                    // We simulate the part starting at `col_idx_in`.
                    // We don't need a full table. We just simulate the path? 
                    // No, `?` branches. We need probabilities or max values.
                    // We need to know the max score at row r, col c.
                    // This is exactly the DP table.
                    // Okay, let's keep `part_simulator` simple: It computes the *entire* gain vector for one part.
                    // But the interface `gain_out` is scalar.
                    // Maybe `part_simulator` should be instantiated C times? No.
                    // Maybe `top` should contain the DP logic, and `part_simulator` is just a helper?
                    // The prompt asks to generate Verilog for `top` and `part_simulator`.
                    // Let's make `part_simulator` compute the gain for `col_idx_in`.
                    // We will compute `dp[r][c]` for all r, but only for columns relevant to `col_idx_in`?
                    // No, `?` links to neighbors. 
                    // Let's just implement `part_simulator` to compute the gain for `col_idx_in` by doing a full DP calculation 
                    // but only storing the necessary states for the current row.
                    // We need `dp[r]` and `dp[r+1]`.
                    // We need to know `dp[r+1][c-1]` and `dp[r+1][c+1]`.
                    // So if we calculate column `c`, we need neighbors `c-1`, `c+1` of the row below.
                    // To support `?` effectively, we really need to compute the whole row or a window.
                    // Let's change `part_simulator` to output a `valid` signal when it's done with the column.
                    // And `top` will loop through columns.
                    // To do this efficiently, `part_simulator` must be able to handle multiple requests efficiently.
                    // Let's implement `part_simulator` as a state machine that computes the whole gain vector once.
                    // And we modify the interface slightly to support streaming the result.
                    // Wait, I cannot modify the interface.
                    // Interface: `input col_idx_in`, `output gain_out`.
                    // This implies `col_idx_in` selects the result.
                    // So `part_simulator` MUST calculate the whole gain vector to answer queries for any `col_idx_in`.
                    // But it's a state machine. It runs once. 
                    // So `top` calls `part_simulator` once (or waits for it to be ready).
                    // Then `part_simulator` is ready with the vector.
                    // How does `top` read different columns? 
                    // Maybe `col_idx_in` is used during calculation to limit scope? 
                    // No, standard DP needs neighbors.
                    // 
                    // ALTERNATIVE: `top` instantiates `part_simulator`.
                    // `part_simulator` computes gain for `col_idx_in` *on the fly*.
                    // It calculates DP row by row.
                    // State `CALC_UP`: It needs `dp[r+1][c-1]` and `dp[r+1][c+1]`.
                    // It can store `dp[r+1]` in registers.
                    // Width C <= 50. 50*32 = 1600 bits. This is acceptable.
                    // So `part_simulator` can store `dp_buffer[0:49]`.
                    // It calculates from bottom to top.
                    // `CALC_BOTTOM`: Fill buffer with `score[c]`.
                    // `CALC_UP`: Update buffer in place? No, need old values.
                    // Use `dp_buffer` for current row `r`, and `dp_next` for `r+1`.
                    // Iterate `r` from R-2 down to 0.
                    // Update `dp_buffer[c]` based on `dp_next[...]`.
                    // Then `dp_next` = `dp_buffer` for next iteration.
                    // Wait, `dp_buffer` is overwritten.
                    // We need to preserve `dp_next` while calculating `dp_current`.
                    // Or we can just use a 2-row buffer: `dp_row_below` and `dp_row_current`.
                    // Yes. `dp_row_below` stores values for row `r+1`. `dp_row_current` stores values for row `r`.
                    // `dp_row_current` updates based on `dp_row_below`.
                    // Then `dp_row_below` <= `dp_row_current`. (Wait, `dp_row_current` is the new row above).
                    // 
                    // Logic:
                    // Init: `dp_row_below[c]` = score[c] for all c.
                    // Loop `r` from R-2 to 0:
                    //   For each `c` in 0..C-1:
                    //     Read grid[r][c].
                    //     Compute val based on `dp_row_below`.
                    //     Store in `dp_row_current[c]`.
                    //   End Loop.
                    //   `dp_row_below` = `dp_row_current`.
                    // End Loop.
                    // Result: `dp_row_below` contains DP[0][c] for all c.
                    // 
                    // Optimization: We can do this in a single cycle if we unroll, but it's large logic.
                    // Let's do it over cycles.
                    // 
                    // `part_simulator` needs to support `col_idx_in`.
                    // Does it output `gain_out` for `col_idx_in`?
                    // Yes. 
                    // So, after calculating the full vector `dp_row_below` (which is DP[0][*]),
                    // we can just output `dp_row_below[col_idx_in]`.
                    // BUT `col_idx_in` might change while we are calculating.
                    // So `top` should keep `col_idx_in` constant during one part simulation.
                    // 
                    // Interface fix: `part_simulator` will iterate `r` and `c` internally.
                    // It will use `col_idx_in` *only* to select the output.
                    // 
                    // Let's refine `part_simulator` states:
                    // IDLE -> LOAD_GRID (if needed, or we assume grid is static in memory? 
                    // The prompt says `input grid_row [0:49]`. This is likely the current row stream.
                    // But we need the whole grid for DP. 
                    // So `LOAD_GRID` must read all rows.
                    // Since `grid_row` is an array input, maybe it is a wire for the current row index.
                    // Let's assume `grid_row` is valid for the whole duration, and we use `row_ptr` to index it.
                    // Wait, `grid_row` is `input [7:0] grid_row [0:49]`. 
                    // This means 50x8 bits input. 
                    // If the grid is 50 rows, how do we get 50 rows? 
                    // "flattened grid rows, one row at a time"
                    // This implies `grid_row` updates every cycle.
                    // We need 50 cycles to load.
                    // We store it in `grid_mem`.
                    // 
                    // `top` drives `grid_row` and `grid_row_valid`.
                    // `part_simulator` captures.
                    // 
                    // Let's implement `part_simulator` to capture the grid.
                    // Then run DP.
                    // Then output `gain_out` for `col_idx_in`.
                    // 
                    // Wait, `part_simulator` output `valid_out` and `done`.
                    // `top` waits for `valid_out`.
                    // `valid_out` is high for one cycle? Or held?
                    // Let's make `valid_out` high for one cycle when result is ready.
                    // 
                    // SUMMARY OF `part_simulator` FSM:
                    // 1. IDLE: Wait for `start_dp`.
                    // 2. LOAD: Iterate `load_row_ptr` 0..R-1. Capture `grid_row` into `grid_mem[load_row_ptr]`.
                    // 3. DP_INIT: Fill `dp_row_below` with `score`.
                    // 4. DP_LOOP: Iterate `r` from R-2 down to 0.
                    //    Inside: Iterate `c` from 0 to C-1.
                    //       Compute `dp_row_current[c]` using `grid_mem[r][c]` and `dp_row_below`.
                    //       Update `dp_row_below` <= `dp_row_current` after row complete.
                    // 5. OUTPUT: Set `gain_out` = `dp_row_below[col_idx_in]`. High `valid_out`.
                    //    Then back to IDLE.
                    // 
                    // Wait, DP loop state: 
                    // To avoid 2D loops in FSM (which are hard), use single loop counter `calc_idx`.
                    // `calc_idx` goes from 0 to (R-2)*C + C-1.
                    // Or better: Outer loop `r`, Inner loop `c`.
                    // 
                    // Let's use `r_cnt` and `c_cnt`.
                    // 
                    // IMPLEMENTATION DETAILS:
                    // 
                    // Edge case: `grid_mem` storage. 
                    // We need to store the grid to access it row by row for DP.
                    // Size 50x50x8 = 20000 bits. OK.
                    // 
                    // Edge case: `score` input. 
                    // `score` is `input [31:0] score [0:49]`. 
                    // This is a bus. We need to capture it or access it.
                    // We can store `score` in a register array too.
                    // Let's capture it in `load_grid` state if possible, or have a separate state.
                    // 
                    // Let's code `part_simulator` carefully.
                end
            endcase
        end
    end

    // To be synthesizable, we need to be careful with array accesses inside always block.
    // We will split the DP calculation into explicit states.
    // State CALC_UP_ROW: Calculate one row.
    // State CALC_UP_ROW_INNER: Calculate one cell in the row.
    
    // Actually, let's rewrite `part_simulator` cleanly.
    
endmodule

module part_simulator (
    input clk,
    input rst_n,
    input [5:0] R,
    input [5:0] C,
    input start_dp,
    input [7:0] grid_row [0:49], 
    input grid_row_valid,
    input [31:0] score [0:49],
    input [5:0] col_idx_in,
    output reg [31:0] gain_out,
    output reg valid_out,
    output reg done
);

    // Grid Memory
    reg [7:0] grid_mem [0:49][0:49];
    reg [31:0] score_mem [0:49];
    
    // DP Registers (Double buffered for rows)
    reg [31:0] dp_row_below [0:49];
    reg [31:0] dp_row_current [0:49];
    
    // State Machine
    localparam S_IDLE = 0;
    localparam S_LOAD_GRID = 1;
    localparam S_LOAD_SCORE = 2;
    localparam S_DP_INIT = 3;
    localparam S_DP_CALC = 4;
    localparam S_DP_UPDATE = 5;
    localparam S_OUTPUT = 6;
    
    reg [3:0] state;
    reg [5:0] row_cnt;
    reg [5:0] col_cnt;
    
    integer i; // for loop in reset/combinational logic
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            valid_out <= 0;
            done <= 0;
            gain_out <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    valid_out <= 0;
                    done <= 0;
                    if (start_dp) begin
                        state <= S_LOAD_GRID;
                        row_cnt <= 0;
                    end
                end

                S_LOAD_GRID: begin
                    // Capture grid_row (provided as a vector of 50 cols)
                    // We assume grid_row_valid is high for every row during loading.
                    // Or we assume grid_row is static and we just iterate rows.
                    // Given the interface, let's iterate row_cnt.
                    // We write the current grid_row into grid_mem[row_cnt].
                    // Wait, if we iterate rows, we need 50 cycles.
                    // The testbench must provide a new `grid_row` each cycle.
                    // Or `grid_row` is the whole grid? No "one row at a time".
                    
                    // Let's copy grid_row to grid_mem[row_cnt]
                    for (int c = 0; c < 50; c++) begin
                        if (c < C) grid_mem[row_cnt][c] <= grid_row[c];
                    end
                    
                    if (row_cnt == R - 1) begin
                        state <= S_LOAD_SCORE; // Move to load score
                        row_cnt <= 0;
                    end else begin
                        row_cnt <= row_cnt + 1;
                    end
                end

                S_LOAD_SCORE: begin
                    // The problem says input `score` is a vector [0:49].
                    // We capture it once.
                    // Since `score` is an input port (array), we can just read it.
                    // But to make it memory-like, let's copy it to `score_mem`.
                    for (int c = 0; c < 50; c++) begin
                        if (c < C) score_mem[c] <= score[c];
                    end
                    state <= S_DP_INIT;
                end

                S_DP_INIT: begin
                    // Initialize dp_row_below with score_mem
                    for (int c = 0; c < 50; c++) begin
                        if (c < C) dp_row_below[c] <= score_mem[c];
                        else dp_row_below[c] <= 0;
                    end
                    // Start calculation from row R-2 down to 0
                    if (R > 1) begin
                        row_cnt <= R - 2;
                        state <= S_DP_CALC;
                        col_cnt <= 0;
                    end else begin
                        // If R=1, we are done, result is in dp_row_below
                        state <= S_OUTPUT;
                    end
                end

                S_DP_CALC: begin
                    // Calculate dp_row_current[col_cnt] based on dp_row_below and grid
                    // Grid cell: grid_mem[row_cnt][col_cnt]
                    // Source row for dp is row_cnt + 1.
                    
                    case (grid_mem[row_cnt][col_cnt])
                        8'h2E: begin // '.'
                            dp_row_current[col_cnt] <= dp_row_below[col_cnt];
                        end
                        8'h58: begin // 'X'
                            dp_row_current[col_cnt] <= 0;
                        end
                        8'h4C: begin // 'L'
                            if (col_cnt > 0)
                                dp_row_current[col_cnt] <= dp_row_below[col_cnt - 1];
                            else
                                dp_row_current[col_cnt] <= 0;
                        end
                        8'h52: begin // 'R'
                            if (col_cnt < C - 1)
                                dp_row_current[col_cnt] <= dp_row_below[col_cnt + 1];
                            else
                                dp_row_current[col_cnt] <= 0;
                        end
                        8'h3F: begin // '?'
                            // Max of L and R
                            // L neighbor
                            wire [31:0] val_l = (col_cnt > 0) ? dp_row_below[col_cnt - 1] : 0;
                            // R neighbor
                            wire [31:0] val_r = (col_cnt < C - 1) ? dp_row_below[col_cnt + 1] : 0;
                            dp_row_current[col_cnt] <= (val_l > val_r) ? val_l : val_r;
                        end
                        default: dp_row_current[col_cnt] <= dp_row_below[col_cnt];
                    endcase

                    if (col_cnt == C - 1) begin
                        state <= S_DP_UPDATE;
                    end else begin
                        col_cnt <= col_cnt + 1;
                    end
                end

                S_DP_UPDATE: begin
                    // Copy dp_row_current to dp_row_below
                    // And decrement row_cnt
                    for (int c = 0; c < 50; c++) begin
                        if (c < C) dp_row_below[c] <= dp_row_current[c];
                    end
                    
                    if (row_cnt == 0) begin
                        state <= S_OUTPUT;
                    end else begin
                        row_cnt <= row_cnt - 1;
                        col_cnt <= 0;
                        state <= S_DP_CALC;
                    end
                end

                S_OUTPUT: begin
                    // Output the value at col_idx_in
                    // dp_row_below now holds DP[0][*]
                    gain_out <= dp_row_below[col_idx_in];
                    valid_out <= 1'b1;
                    done <= 1'b1;
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule