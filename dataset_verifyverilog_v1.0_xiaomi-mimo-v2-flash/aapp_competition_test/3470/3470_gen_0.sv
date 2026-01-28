module MinesweeperCornerPuzzle(
    input clk,
    input rst_n,
    input start,
    input [9:0] n,
    output reg done,
    output reg [12:0] result_count,
    output reg [12:0] result_indices [0:4003],
    output reg result_valid
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_TOTAL = 3'd1;
    localparam [2:0] FIND_SAFES = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    // Registers and wires
    reg [2:0] state, next_state;
    reg [12:0] total_cells;      // 4*n + 4, max 4004
    reg [12:0] current_idx;      // Current index to check (1 to total_cells)
    reg [12:0] safe_count;       // Counter for safe cells
    reg [12:0] index_counter;    // Index for result array
    reg [12:0] temp_idx;         // Temporary index storage
    reg is_safe_flag;            // Flag to indicate if current cell is safe
    reg parity_n;                // n mod 2: 0=even, 1=odd
    reg [7:0] cycle_count;       // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd100;

    integer i;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CALC_TOTAL;
                else
                    next_state = IDLE;
            end
            CALC_TOTAL: begin
                next_state = FIND_SAFES;
            end
            FIND_SAFES: begin
                if (current_idx > total_cells)
                    next_state = FINISH;
                else if (cycle_count >= MAX_CYCLES)
                    next_state = FINISH;
                else
                    next_state = FIND_SAFES;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_count <= 13'd0;
            result_valid <= 1'b0;
            total_cells <= 13'd0;
            current_idx <= 13'd0;
            safe_count <= 13'd0;
            index_counter <= 13'd0;
            temp_idx <= 13'd0;
            is_safe_flag <= 1'b0;
            parity_n <= 1'b0;
            cycle_count <= 8'd0;
            for (i = 0; i < 4004; i = i + 1) begin
                result_indices[i] <= 13'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_valid <= 1'b0;
                    if (start) begin
                        // Calculate parity of n
                        parity_n <= n[0];  // LSB is parity
                    end
                end

                CALC_TOTAL: begin
                    // total_cells = 4*n + 4
                    total_cells <= ({n, 2'b00} + 13'd4);  // 4*n + 4
                    current_idx <= 13'd1;
                    safe_count <= 13'd0;
                    index_counter <= 13'd0;
                    cycle_count <= 8'd0;
                end

                FIND_SAFES: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (current_idx <= total_cells) begin
                        // Check if current_idx is safe
                        // Rule: Safe when parity matches
                        // For odd n (parity_n=1): odd indices are safe
                        // For even n (parity_n=0): even indices are safe
                        
                        if (parity_n == 1'b1) begin
                            // n is odd: safe if current_idx is odd
                            if (current_idx[0] == 1'b1) begin
                                is_safe_flag <= 1'b1;
                            end else begin
                                is_safe_flag <= 1'b0;
                            end
                        end else begin
                            // n is even: safe if current_idx is even (but not 0)
                            if (current_idx[0] == 1'b0 && current_idx != 13'd0) begin
                                is_safe_flag <= 1'b1;
                            end else begin
                                is_safe_flag <= 1'b0;
                            end
                        end
                        
                        // Store if safe
                        if (is_safe_flag) begin
                            if (index_counter < 13'd4004) begin
                                result_indices[index_counter] <= current_idx;
                                safe_count <= safe_count + 13'd1;
                                index_counter <= index_counter + 13'd1;
                            end
                        end
                        
                        // Increment current index
                        current_idx <= current_idx + 13'd1;
                    end
                end

                FINISH: begin
                    result_count <= safe_count;
                    result_valid <= 1'b1;
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule