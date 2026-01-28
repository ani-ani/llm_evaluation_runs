module will_it_fly(
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input [7:0] arr [0:3],
    input [15:0] w,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] CHECK_PALINDROME = 3'd1;
    localparam [2:0] CALC_SUM       = 3'd2;
    localparam [2:0] COMPARE        = 3'd3;
    localparam [2:0] DONE_TRUE      = 3'd4;
    localparam [2:0] DONE_FALSE     = 3'd5;

    reg [2:0] state, next_state;
    reg [2:0] i;                          // Index for palindrome check (0 to 3)
    reg [2:0] j;                          // Index for palindrome check (len-1-i)
    reg [15:0] sum;                       // Accumulated sum
    reg palindrome_valid;                 // Flag for palindrome check
    reg [2:0] calc_idx;                   // Index for sum calculation
    reg [2:0] cycle_count;                // Cycle counter for timeout
    localparam [2:0] MAX_CYCLES = 3'd7;   // 7 cycles for max operations

    // State register and reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 3'd0;
            j <= 3'd0;
            sum <= 16'd0;
            palindrome_valid <= 1'b1;
            calc_idx <= 3'd0;
            cycle_count <= 3'd0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            // Default assignments for non-reset states
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 3'd0;
                end
                
                CHECK_PALINDROME: begin
                    if (arr[i] != arr[j]) begin
                        palindrome_valid <= 1'b0;
                    end
                    i <= i + 3'd1;
                    j <= j - 3'd1;
                end
                
                CALC_SUM: begin
                    if (calc_idx < len) begin
                        sum <= sum + {8'd0, arr[calc_idx]};
                        calc_idx <= calc_idx + 3'd1;
                    end
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 3'd1;
                end
                
                DONE_TRUE: begin
                    result <= 1'b1;
                    done <= 1'b1;
                end
                
                DONE_FALSE: begin
                    result <= 1'b0;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_PALINDROME;
                end else begin
                    next_state = IDLE;
                end
            end
            
            CHECK_PALINDROME: begin
                // Check if all pairs compared (i >= j or i >= len-1-i)
                if ((i >= len - 3'd1) || (i >= (len >> 1))) begin
                    next_state = CALC_SUM;
                end else begin
                    next_state = CHECK_PALINDROME;
                end
            end
            
            CALC_SUM: begin
                if (calc_idx >= len) begin
                    next_state = COMPARE;
                end else begin
                    next_state = CALC_SUM;
                end
            end
            
            COMPARE: begin
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_FALSE; // Timeout fallback
                end else if (palindrome_valid && (sum <= w)) begin
                    next_state = DONE_TRUE;
                end else begin
                    next_state = DONE_FALSE;
                end
            end
            
            DONE_TRUE: begin
                next_state = IDLE;
            end
            
            DONE_FALSE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule