module domino_min_sum(
    input clk,
    input rst_n,
    input start,
    input grid_valid,
    input [15:0] grid_data,
    input [5:0] grid_addr,
    input [3:0] K,
    output reg [15:0] result,
    output reg done,
    output reg ready
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD_GRID = 4'd1;
    localparam [3:0] INIT_SOLVE = 4'd2;
    localparam [3:0] CHECK_CELL = 4'd3;
    localparam [3:0] PLACE_DOMINO = 4'd4;
    localparam [3:0] BACKTRACK = 4'd5;
    localparam [3:0] UPDATE_MIN = 4'd6;
    localparam [3:0] DONE_STATE = 4'd7;

    // Grid storage (64 entries x 16 bits)
    reg [15:0] grid [0:63];
    reg [5:0] grid_write_addr;
    reg grid_loaded;

    // DFS control
    reg [3:0] state;
    reg [5:0] current_cell;
    reg [5:0] stack_ptr;
    reg [5:0] stack_cell [0:63];
    reg [5:0] stack_remaining [0:63];
    reg [63:0] coverage_mask;
    reg [15:0] current_sum;
    reg [15:0] min_sum;
    reg [3:0] remaining_dominoes;
    reg [5:0] cell_counter;
    reg [5:0] row, col;
    reg [5:0] next_cell;
    reg [15:0] total_grid_sum;
    reg [15:0] covered_sum;

    // Cycle counter for timeout
    reg [16:0] cycle_count;
    localparam [16:0] MAX_CYCLES = 17'd100000;

    // Ready signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready <= 1'b0;
        end else begin
            ready <= (state == IDLE) || (state == LOAD_GRID && grid_loaded);
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            grid_write_addr <= 6'd0;
            grid_loaded <= 1'b0;
            current_cell <= 6'd0;
            stack_ptr <= 6'd0;
            coverage_mask <= 64'd0;
            current_sum <= 16'd0;
            min_sum <= 16'd64000;
            remaining_dominoes <= 4'd0;
            cell_counter <= 6'd0;
            row <= 6'd0;
            col <= 6'd0;
            next_cell <= 6'd0;
            total_grid_sum <= 16'd0;
            covered_sum <= 16'd0;
            cycle_count <= 17'd0;
            done <= 1'b0;
            result <= 16'd0;

            // Initialize stack
            integer i;
            for (i = 0; i < 64; i = i + 1) begin
                stack_cell[i] <= 6'd0;
                stack_remaining[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD_GRID;
                        grid_write_addr <= 6'd0;
                        grid_loaded <= 1'b0;
                        total_grid_sum <= 16'd0;
                    end
                end

                LOAD_GRID: begin
                    if (grid_valid) begin
                        grid[grid_addr] <= grid_data;
                        total_grid_sum <= total_grid_sum + grid_data;
                        if (grid_write_addr == 63) begin
                            grid_loaded <= 1'b1;
                            state <= INIT_SOLVE;
                        end else begin
                            grid_write_addr <= grid_write_addr + 6'd1;
                        end
                    end
                end

                INIT_SOLVE: begin
                    // Initialize DFS
                    coverage_mask <= 64'd0;
                    current_sum <= total_grid_sum;
                    min_sum <= current_sum;
                    remaining_dominoes <= K;
                    current_cell <= 6'd0;
                    stack_ptr <= 6'd0;
                    cell_counter <= 6'd0;
                    covered_sum <= 16'd0;
                    cycle_count <= 17'd0;
                    state <= CHECK_CELL;
                end

                CHECK_CELL: begin
                    cycle_count <= cycle_count + 17'd1;
                    
                    // Check if we've placed all dominoes
                    if (remaining_dominoes == 4'd0) begin
                        // Update minimum sum
                        if (current_sum < min_sum) begin
                            min_sum <= current_sum;
                        end
                        state <= BACKTRACK;
                    end else if (cell_counter == 6'd64) begin
                        // No more cells to check
                        state <= BACKTRACK;
                    end else begin
                        // Check if current cell is uncovered
                        if (!coverage_mask[cell_counter]) begin
                            current_cell <= cell_counter;
                            state <= PLACE_DOMINO;
                        end else begin
                            // Move to next cell
                            cell_counter <= cell_counter + 6'd1;
                        end
                    end
                end

                PLACE_DOMINO: begin
                    // Try placing domino horizontally (right)
                    if (current_cell % 8 != 7) begin
                        next_cell <= current_cell + 6'd1;
                        if (!coverage_mask[next_cell]) begin
                            // Place horizontal domino
                            coverage_mask[current_cell] <= 1'b1;
                            coverage_mask[next_cell] <= 1'b1;
                            current_sum <= current_sum - grid[current_cell] - grid[next_cell];
                            covered_sum <= covered_sum + grid[current_cell] + grid[next_cell];
                            
                            // Push state to stack
                            stack_cell[stack_ptr] <= current_cell + 6'd1;
                            stack_remaining[stack_ptr] <= remaining_dominoes - 4'd1;
                            stack_ptr <= stack_ptr + 6'd1;
                            
                            remaining_dominoes <= remaining_dominoes - 4'd1;
                            cell_counter <= 6'd0;
                            state <= CHECK_CELL;
                        end
                    end else begin
                        // Try placing domino vertically (down)
                        if (current_cell < 56) begin
                            next_cell <= current_cell + 6'd8;
                            if (!coverage_mask[next_cell]) begin
                                // Place vertical domino
                                coverage_mask[current_cell] <= 1'b1;
                                coverage_mask[next_cell] <= 1'b1;
                                current_sum <= current_sum - grid[current_cell] - grid[next_cell];
                                covered_sum <= covered_sum + grid[current_cell] + grid[next_cell];
                                
                                // Push state to stack
                                stack_cell[stack_ptr] <= current_cell + 6'd1;
                                stack_remaining[stack_ptr] <= remaining_dominoes - 4'd1;
                                stack_ptr <= stack_ptr + 6'd1;
                                
                                remaining_dominoes <= remaining_dominoes - 4'd1;
                                cell_counter <= 6'd0;
                                state <= CHECK_CELL;
                            end
                        end
                    end
                    
                    // If no placement possible, move to next cell
                    if (state == PLACE_DOMINO) begin
                        cell_counter <= cell_counter + 6'd1;
                        state <= CHECK_CELL;
                    end
                end

                BACKTRACK: begin
                    cycle_count <= cycle_count + 17'd1;
                    
                    // Check timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= UPDATE_MIN;
                    end else if (stack_ptr == 6'd0) begin
                        // Stack is empty, we're done
                        state <= UPDATE_MIN;
                    end else begin
                        // Pop from stack
                        stack_ptr <= stack_ptr - 6'd1;
                        cell_counter <= stack_cell[stack_ptr];
                        remaining_dominoes <= stack_remaining[stack_ptr];
                        
                        // Uncover the domino we placed
                        current_cell <= cell_counter - 6'd1;
                        if (current_cell % 8 != 7 && !coverage_mask[current_cell + 6'd1]) begin
                            // Was horizontal
                            coverage_mask[current_cell] <= 1'b0;
                            coverage_mask[current_cell + 6'd1] <= 1'b0;
                            current_sum <= current_sum + grid[current_cell] + grid[current_cell + 6'd1];
                            covered_sum <= covered_sum - grid[current_cell] - grid[current_cell + 6'd1];
                        end else if (current_cell < 56 && !coverage_mask[current_cell + 6'd8]) begin
                            // Was vertical
                            coverage_mask[current_cell] <= 1'b0;
                            coverage_mask[current_cell + 6'd8] <= 1'b0;
                            current_sum <= current_sum + grid[current_cell] + grid[current_cell + 6'd8];
                            covered_sum <= covered_sum - grid[current_cell] - grid[current_cell + 6'd8];
                        end
                        
                        state <= CHECK_CELL;
                    end
                end

                UPDATE_MIN: begin
                    // Final update of minimum sum
                    if (current_sum < min_sum) begin
                        min_sum <= current_sum;
                    end
                    
                    // Prepare result
                    result <= min_sum;
                    done <= 1'b1;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule