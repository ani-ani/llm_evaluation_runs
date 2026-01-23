module magical_subarray(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [3:0] L,
    input [3:0] R,
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] SETUP      = 3'd1;
    localparam [2:0] COMPUTE    = 3'd2;
    localparam [2:0] CHECK_SUB  = 3'd3;
    localparam [2:0] UPDATE_MAX = 3'd4;
    localparam [2:0] FINISH     = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [2:0] i, j;              // Subarray indices
    reg [7:0] min_val, max_val;  // For current subarray check
    reg [3:0] current_len;       // Length of current subarray
    reg [3:0] max_len;           // Maximum length found
    reg [7:0] arr_reg [0:7];     // Store input array
    reg [3:0] L_reg, R_reg;      // Query range
    reg [1:0] check_idx;         // Index for checking subarray elements
    reg is_magical;              // Flag for current subarray
    reg [7:0] cycle_count;       // Cycle counter
    localparam [7:0] MAX_CYCLES = 8'd200;

    integer k;                   // For loop

    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            i <= 3'd0;
            j <= 3'd0;
            min_val <= 8'd0;
            max_val <= 8'd0;
            current_len <= 4'd0;
            max_len <= 4'd0;
            L_reg <= 4'd0;
            R_reg <= 4'd0;
            check_idx <= 2'd0;
            is_magical <= 1'b0;
            cycle_count <= 8'd0;
            for (k = 0; k < 8; k = k + 1) begin
                arr_reg[k] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Store input array
                        arr_reg[0] <= arr_0;
                        arr_reg[1] <= arr_1;
                        arr_reg[2] <= arr_2;
                        arr_reg[3] <= arr_3;
                        arr_reg[4] <= arr_4;
                        arr_reg[5] <= arr_5;
                        arr_reg[6] <= arr_6;
                        arr_reg[7] <= arr_7;
                        // Store query range
                        L_reg <= L;
                        R_reg <= R;
                    end
                end
                
                SETUP: begin
                    max_len <= 4'd0;
                    i <= L_reg - 4'd1;  // Convert to 0-indexed
                end
                
                COMPUTE: begin
                    // Reset subarray state for new i
                    min_val <= arr_reg[i];
                    max_val <= arr_reg[i];
                    j <= i;
                    is_magical <= 1'b1;
                end
                
                CHECK_SUB: begin
                    // Check if arr[j] is within [min_val, max_val]
                    if (arr_reg[j] < min_val || arr_reg[j] > max_val) begin
                        is_magical <= 1'b0;
                    end else begin
                        // Update min/max for future checks
                        if (arr_reg[j] < min_val) min_val <= arr_reg[j];
                        if (arr_reg[j] > max_val) max_val <= arr_reg[j];
                    end
                end
                
                UPDATE_MAX: begin
                    if (is_magical) begin
                        current_len <= j - i + 4'd1;
                        if (j - i + 4'd1 > max_len) begin
                            max_len <= j - i + 4'd1;
                        end
                    end
                end
                
                FINISH: begin
                    result <= max_len;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 4'd0;
                    done <= 1'b0;
                end
            endcase
            
            // Increment cycle counter
            cycle_count <= cycle_count + 8'd1;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) next_state = SETUP;
            end
            
            SETUP: begin
                if (i < R_reg) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = FINISH;
                end
            end
            
            COMPUTE: begin
                next_state = CHECK_SUB;
            end
            
            CHECK_SUB: begin
                next_state = UPDATE_MAX;
            end
            
            UPDATE_MAX: begin
                if (j < R_reg - 4'd1) begin
                    // Continue with same i, next j
                    next_state = CHECK_SUB;
                    // Note: j increment happens in next cycle by reordering
                    // We need to check current j first, then increment
                end else begin
                    // Move to next i
                    next_state = SETUP;
                    i = i + 3'd1;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
        
        // Manual increment of j in UPDATE_MAX
        if (state == UPDATE_MAX && j < R_reg - 4'd1 && is_magical) begin
            j = j + 3'd1;
        end
    end

endmodule