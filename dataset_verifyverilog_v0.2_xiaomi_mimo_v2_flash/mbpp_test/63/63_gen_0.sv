module max_difference(
    input clk,
    input rst_n,
    input start,
    input [4:0] num_pairs,
    input [7:0] pairs [0:7],
    output reg [7:0] max_diff,
    output reg done
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam READ_PAIR = 3'b001;
    localparam COMPUTE_DIFF = 3'b010;
    localparam UPDATE_MAX = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] pair_index; // Index for current pair (0-7)
    reg [7:0] a_val;
    reg [7:0] b_val;
    reg [7:0] diff_temp;
    reg [7:0] max_diff_next;
    reg done_next;

    // State transition logic
    always @(*) begin
        next_state = state;
        done_next = 1'b0;
        max_diff_next = max_diff;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = READ_PAIR;
                end
            end
            
            READ_PAIR: begin
                next_state = COMPUTE_DIFF;
            end
            
            COMPUTE_DIFF: begin
                next_state = UPDATE_MAX;
            end
            
            UPDATE_MAX: begin
                // Check if this is the last pair
                if (pair_index + 1 >= num_pairs) begin
                    next_state = DONE;
                end else begin
                    next_state = READ_PAIR;
                end
            end
            
            DONE: begin
                done_next = 1'b1;
                // Stay in DONE until reset
                if (!rst_n) begin
                    next_state = IDLE;
                end else begin
                    next_state = DONE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

    // State register and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pair_index <= 3'b0;
            max_diff <= 8'b0;
            done <= 1'b0;
            a_val <= 8'b0;
            b_val <= 8'b0;
            diff_temp <= 8'b0;
        end else begin
            state <= next_state;
            done <= done_next;
            max_diff <= max_diff_next;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        pair_index <= 3'b0;
                        max_diff <= 8'b0;
                        done <= 1'b0;
                    end
                end
                
                READ_PAIR: begin
                    a_val <= pairs[pair_index * 2];
                    b_val <= pairs[pair_index * 2 + 1];
                end
                
                COMPUTE_DIFF: begin
                    // Compute absolute difference: abs(b - a)
                    if (b_val >= a_val) begin
                        diff_temp <= b_val - a_val;
                    end else begin
                        diff_temp <= a_val - b_val;
                    end
                end
                
                UPDATE_MAX: begin
                    // Update max if current diff is larger
                    if (diff_temp > max_diff) begin
                        max_diff_next = diff_temp;
                        max_diff <= diff_temp;
                    end
                    // Increment pair index
                    if (pair_index + 1 < num_pairs) begin
                        pair_index <= pair_index + 1;
                    end
                end
                
                DONE: begin
                    // Hold done flag high
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule