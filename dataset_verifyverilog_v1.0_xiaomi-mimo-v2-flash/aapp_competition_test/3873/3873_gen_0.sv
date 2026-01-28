module generate_swap_pairs(
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    output reg [2:0] pair_a,
    output reg [2:0] pair_b,
    output reg valid,
    output reg done,
    output reg possible
);

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] CHECK_N      = 3'd1;
    localparam [2:0] IMPOSSIBLE   = 3'd2;
    localparam [2:0] INIT_PAIRS   = 3'd3;
    localparam [2:0] OUTPUT_PAIR  = 3'd4;
    localparam [2:0] NEXT_PAIR    = 3'd5;
    localparam [2:0] FINISH       = 3'd6;

    // Registers
    reg [2:0] state, next_state;
    reg [2:0] i, j;               // Current pair indices
    reg [5:0] cycle_count;        // Up to 28 pairs + overhead
    localparam [5:0] MAX_CYCLES = 6'd32;

    // Helper wires
    wire [2:0] n_mod4;
    wire [2:0] i_plus_1;
    wire [2:0] j_plus_1;
    
    assign n_mod4 = n & 3'b111;    // n <= 8, so n_mod4 is just n mod 4
    assign i_plus_1 = i + 3'd1;
    assign j_plus_1 = j + 3'd1;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CHECK_N;
                else
                    next_state = IDLE;
            end
            
            CHECK_N: begin
                if (n > 3'd8 || (n_mod4 == 3'd2 || n_mod4 == 3'd3))
                    next_state = IMPOSSIBLE;
                else
                    next_state = INIT_PAIRS;
            end
            
            IMPOSSIBLE: begin
                next_state = FINISH;
            end
            
            INIT_PAIRS: begin
                next_state = OUTPUT_PAIR;
            end
            
            OUTPUT_PAIR: begin
                next_state = NEXT_PAIR;
            end
            
            NEXT_PAIR: begin
                if (i >= n - 3'd2) begin
                    if (j >= n - 3'd1)
                        next_state = FINISH;
                    else
                        next_state = FINISH;  // Should not reach here
                end else begin
                    next_state = OUTPUT_PAIR;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // State register and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pair_a <= 3'd0;
            pair_b <= 3'd0;
            valid <= 1'b0;
            done <= 1'b0;
            possible <= 1'b1;  // Reset default
            i <= 3'd0;
            j <= 3'd0;
            cycle_count <= 6'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 6'd0;
                end
                
                CHECK_N: begin
                    // Check if valid: n <= 8 AND (n % 4 == 0 OR n % 4 == 1)
                    if (n > 3'd8 || (n_mod4 == 3'd2 || n_mod4 == 3'd3)) begin
                        possible <= 1'b0;
                    end else begin
                        possible <= 1'b1;
                    end
                end
                
                IMPOSSIBLE: begin
                    // For impossible cases, possible is already 0
                    // No special output needed
                end
                
                INIT_PAIRS: begin
                    i <= 3'd0;
                    j <= 3'd1;
                    cycle_count <= 6'd0;
                end
                
                OUTPUT_PAIR: begin
                    pair_a <= i;
                    pair_b <= j;
                    valid <= 1'b1;
                    cycle_count <= cycle_count + 6'd1;
                end
                
                NEXT_PAIR: begin
                    valid <= 1'b0;
                    // Move to next pair: increment j, if j reaches n-1, reset j and increment i
                    if (j < n - 3'd1) begin
                        j <= j + 3'd1;
                    end else begin
                        // j reached n-1, reset to i+2, increment i
                        j <= i + 3'd2;
                        i <= i + 3'd1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    valid <= 1'b0;
                end
            endcase
        end
    end

endmodule