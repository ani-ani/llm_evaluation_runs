module purification_solver (
    input clk,
    input rst_n,
    input start,
    input [3:0] grid_row_idx,
    input [3:0] grid_col_idx,
    input cell_type,
    output reg [1:0] result_row [0:3],
    output reg [1:0] result_col [0:3],
    output reg [2:0] result_count,
    output reg done,
    output reg valid
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam LOAD_GRID = 3'b001;
    localparam SOLVE = 3'b010;
    localparam OUTPUT = 3'b011;

    reg [2:0] current_state;
    reg [2:0] next_state;
    
    // Memory for the 4x4 grid
    reg grid [0:3][0:3];
    
    // Cycle counter for 50 cycle latency requirement
    reg [5:0] cycle_count;
    
    // Helper flags for solving state
    reg strategy_row_success;
    reg strategy_col_success;

    // State Transition Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start) next_state = LOAD_GRID;
                else next_state = IDLE;
            end
            
            LOAD_GRID: begin
                // Load for 16 cycles (cycles 1 to 16)
                if (cycle_count >= 16)
                    next_state = SOLVE;
                else
                    next_state = LOAD_GRID;
            end
            
            SOLVE: begin
                // Spend cycles 17 to 48 calculating
                if (cycle_count >= 49)
                    next_state = OUTPUT;
                else
                    next_state = SOLVE;
            end
            
            OUTPUT: begin
                // At cycle 50, assert done. Return to IDLE if start is low (or next cycle).
                // To strictly meet "Result valid 50 clock cycles", we assert done in this state.
                // We return to IDLE on the next clock edge (cycle 51) if we assume the operation is done.
                // Or we can stay in OUTPUT until start goes low. 
                // Let's go to IDLE immediately after reaching cycle 50 (i.e. on cycle 51).
                // But cycle_count stops at 50. 
                // Let's go to IDLE. If start is still high, IDLE will transition to LOAD_GRID again.
                if (cycle_count >= 50)
                    next_state = IDLE;
                else
                    next_state = OUTPUT;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic (State, Counter, Outputs)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            cycle_count <= 0;
            done <= 0;
            valid <= 0;
            result_count <= 0;
            strategy_row_success <= 0;
            strategy_col_success <= 0;
            // Initialize results array
            result_row[0] <= 0; result_col[0] <= 0;
            result_row[1] <= 0; result_col[1] <= 0;
            result_row[2] <= 0; result_col[2] <= 0;
            result_row[3] <= 0; result_col[3] <= 0;
        end else begin
            current_state <= next_state;
            
            // Cycle Counter Management
            if (current_state == IDLE && start) begin
                cycle_count <= 1;
            end else if (current_state != IDLE) begin
                if (cycle_count < 50)
                    cycle_count <= cycle_count + 1;
            end else begin
                cycle_count <= 0;
            end
            
            // Datapath Logic
            case (current_state)
                IDLE: begin
                    done <= 0;
                    valid <= 0;
                    strategy_row_success <= 0;
                    strategy_col_success <= 0;
                end
                
                LOAD_GRID: begin
                    // Cycle 1 to 16: Sample inputs
                    if (cycle_count >= 1 && cycle_count <= 16) begin
                        grid[grid_row_idx[1:0]][grid_col_idx[1:0]] <= cell_type;
                    end
                end
                
                SOLVE: begin
                    // Cycle 17-48: Calculation Phase
                    // We use specific cycle counts to perform checks to ensure sequential processing.
                    
                    // Row Strategy Check (Cycles 17-20)
                    if (cycle_count == 17) begin
                        // Check Row 0
                        if (!(grid[0][0] && grid[0][1] && grid[0][2] && grid[0][3])) begin
                            strategy_row_success <= 1;
                            result_row[0] <= 0;
                            if (!grid[0][0]) result_col[0] <= 0;
                            else if (!grid[0][1]) result_col[0] <= 1;
                            else if (!grid[0][2]) result_col[0] <= 2;
                            else result_col[0] <= 3;
                        end else strategy_row_success <= 0;
                    end
                    else if (cycle_count == 18 && strategy_row_success) begin
                        // Check Row 1
                        if (!(grid[1][0] && grid[1][1] && grid[1][2] && grid[1][3])) begin
                            result_row[1] <= 1;
                            if (!grid[1][0]) result_col[1] <= 0;
                            else if (!grid[1][1]) result_col[1] <= 1;
                            else if (!grid[1][2]) result_col[1] <= 2;
                            else result_col[1] <= 3;
                        end else strategy_row_success <= 0;
                    end
                    else if (cycle_count == 19 && strategy_row_success) begin
                        // Check Row 2
                        if (!(grid[2][0] && grid[2][1] && grid[2][2] && grid[2][3])) begin
                            result_row[2] <= 2;
                            if (!grid[2][0]) result_col[2] <= 0;
                            else if (!grid[2][1]) result_col[2] <= 1;
                            else if (!grid[2][2]) result_col[2] <= 2;
                            else result_col[2] <= 3;
                        end else strategy_row_success <= 0;
                    end
                    else if (cycle_count == 20 && strategy_row_success) begin
                        // Check Row 3
                        if (!(grid[3][0] && grid[3][1] && grid[3][2] && grid[3][3])) begin
                            result_row[3] <= 3;
                            if (!grid[3][0]) result_col[3] <= 0;
                            else if (!grid[3][1]) result_col[3] <= 1;
                            else if (!grid[3][2]) result_col[3] <= 2;
                            else result_col[3] <= 3;
                        end else strategy_row_success <= 0;
                    end
                    
                    // Column Strategy Check (Cycles 21-24)
                    // Only if Row Strategy Failed
                    else if (cycle_count == 21 && !strategy_row_success) begin
                        // Check Col 0
                        if (!(grid[0][0] && grid[1][0] && grid[2][0] && grid[3][0])) begin
                            strategy_col_success <= 1;
                            result_col[0] <= 0;
                            if (!grid[0][0]) result_row[0] <= 0;
                            else if (!grid[1][0]) result_row[0] <= 1;
                            else if (!grid[2][0]) result_row[0] <= 2;
                            else result_row[0] <= 3;
                        end else strategy_col_success <= 0;
                    end
                    else if (cycle_count == 22 && !strategy_row_success && strategy_col_success) begin
                        // Check Col 1
                        if (!(grid[0][1] && grid[1][1] && grid[2][1] && grid[3][1])) begin
                            result_col[1] <= 1;
                            if (!grid[0][1]) result_row[1] <= 0;
                            else if (!grid[1][1]) result_row[1] <= 1;
                            else if (!grid[2][1]) result_row[1] <= 2;
                            else result_row[1] <= 3;
                        end else strategy_col_success <= 0;
                    end
                    else if (cycle_count == 23 && !strategy_row_success && strategy_col_success) begin
                        // Check Col 2
                        if (!(grid[0][2] && grid[1][2] && grid[2][2] && grid[3][2])) begin
                            result_col[2] <= 2;
                            if (!grid[0][2]) result_row[2] <= 0;
                            else if (!grid[1][2]) result_row[2] <= 1;
                            else if (!grid[2][2]) result_row[2] <= 2;
                            else result_row[2] <= 3;
                        end else strategy_col_success <= 0;
                    end
                    else if (cycle_count == 24 && !strategy_row_success && strategy_col_success) begin
                        // Check Col 3
                        if (!(grid[0][3] && grid[1][3] && grid[2][3] && grid[3][3])) begin
                            result_col[3] <= 3;
                            if (!grid[0][3]) result_row[3] <= 0;
                            else if (!grid[1][3]) result_row[3] <= 1;
                            else if (!grid[2][3]) result_row[3] <= 2;
                            else result_row[3] <= 3;
                        end else strategy_col_success <= 0;
                    end
                    
                    // Latch Valid and Count (Cycle 25)
                    else if (cycle_count == 25) begin
                        if (strategy_row_success || strategy_col_success) begin
                            valid <= 1;
                            result_count <= 4;
                        end else begin
                            valid <= 0;
                            result_count <= 0;
                        end
                    end
                end
                
                OUTPUT: begin
                    // Assert Done
                    done <= 1;
                    // Valid and results are already latched from SOLVE state
                end
            endcase
        end
    end

endmodule