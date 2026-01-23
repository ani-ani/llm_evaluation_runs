module rectangular_grid_checker (
    input clk,
    input rst_n,
    input start,
    input [7:0] row_data [7:0],
    input [2:0] row_index,
    input load_row,
    output reg [3:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b001;
    localparam LOAD_GRID = 3'b010;
    localparam PROCESSING = 3'b100;
    localparam DONE = 3'b000; // Use one-hot or binary, keeping it simple with binary
    
    reg [2:0] state;
    reg [2:0] next_state;

    // Grid storage: 8 rows of 8 bits
    reg [7:0] grid [7:0];
    
    // Processing counters
    reg [2:0] i; // rows 0-6
    reg [2:0] j; // cols 0-6
    
    // Accumulated invalid count
    reg [3:0] invalid_count;
    reg [3:0] next_invalid_count;
    
    // Load tracking
    reg [7:0] rows_loaded;
    wire all_rows_loaded;
    assign all_rows_loaded = (rows_loaded == 8'hFF);

    // Control signals
    reg inc_i;
    reg clr_i;
    reg inc_j;
    reg clr_j;
    reg acc_en;
    reg acc_rst;
    reg update_result;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = LOAD_GRID;
                else next_state = IDLE;
            end
            LOAD_GRID: begin
                if (all_rows_loaded) next_state = PROCESSING;
                else next_state = LOAD_GRID;
            end
            PROCESSING: begin
                // Logic: Iterate i 0-6, j 0-6. Total 7x7 = 49 checks.
                // We can process one check per cycle.
                // Latency requirement is 128 cycles, so 49 cycles is well within limit.
                if (i == 3'd6 && j == 3'd6) next_state = DONE;
                else next_state = PROCESSING;
            end
            DONE: begin
                next_state = DONE; // Stay in done until reset
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rows_loaded <= 8'b0;
            result <= 5'b0;
            done <= 1'b0;
            i <= 3'b0;
            j <= 3'b0;
            invalid_count <= 4'b0;
        end else begin
            // Row Loading Logic
            if (state == LOAD_GRID && load_row) begin
                grid[row_index] <= row_data[row_index];
                rows_loaded[row_index] <= 1'b1;
            end else if (state == IDLE) begin
                rows_loaded <= 8'b0;
            end

            // Processing Logic
            if (state == PROCESSING) begin
                // Check condition for current (i, j)
                // a[i][j], a[i+1][j+1], a[i][j+1], a[i+1][j]
                // grid[i][j] etc.
                
                // Check Invalid Corner: diag equal, off-diag different
                // (grid[i][j] == grid[i+1][j+1]) && (grid[i][j+1] != grid[i+1][j])
                
                if ((grid[i][j] == grid[i+1][j+1]) && (grid[i][j+1] != grid[i+1][j])) begin
                    invalid_count <= invalid_count + 1;
                end

                // Update Counters
                if (j == 3'd6) begin
                    j <= 3'd0;
                    if (i == 3'd6) begin
                        i <= 3'd0; // Reset for next time, though we go to DONE
                    end else begin
                        i <= i + 1;
                    end
                end else begin
                    j <= j + 1;
                end
            end else if (state == IDLE) begin
                invalid_count <= 4'b0;
                i <= 3'b0;
                j <= 3'b0;
            end

            // Result Update Logic (at the end of processing)
            // We detect the transition to DONE or check state == PROCESSING and counters maxed
            // Actually, better to update in DONE state if we can, or logic implies we just finished.
            // Let's update when we enter DONE from PROCESSING, or simply based on the counts when done.
            // Since PROCESSING handles the increment, we check the flag transition.
            if (state == PROCESSING && i == 3'd6 && j == 3'd6) begin
                // This is the last cycle of processing logic, next cycle is DONE.
                // We need to capture the final count.
                // Since the increment happens this cycle, invalid_count holds the correct final value.
            end
        end
    end

    // Output Logic (Combinational based on state transition or stored values)
    always @(*) begin
        done = 1'b0;
        if (state == DONE) begin
            done = 1'b1;
            // If we want to include the very last increment in the result:
            // The always block above increments invalid_count in the last cycle.
            // So invalid_count holds the correct value when state switches to DONE.
            if (invalid_count <= 4) result = invalid_count;
            else result = 5;
        end else begin
            result = 0; // Or undefined, but reset to 0 for safety
        end
    end

endmodule
