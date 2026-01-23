module slime_k_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0] k,
    input [7:0] a_0, a_1, a_2, a_3, a_4, a_5, a_6, a_7,
    output reg result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam CHECK_K = 2'b01;
    localparam CHECK_PAIRS = 2'b10;
    localparam FINISH = 2'b11;

    reg [1:0] state, next_state;
    reg result_reg, next_result;
    reg done_reg, next_done;
    reg exists_k, next_exists_k;
    reg [7:0] arr [0:7];
    integer i;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            exists_k <= 1'b0;
        end else begin
            state <= next_state;
            result <= next_result;
            done <= next_done;
            exists_k <= next_exists_k;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        next_result = result;
        next_done = done;
        next_exists_k = exists_k;
        
        case (state)
            IDLE: begin
                next_done = 1'b0;
                if (start) begin
                    next_state = CHECK_K;
                end
            end
            
            CHECK_K: begin
                // Check if k exists in array
                next_exists_k = (a_0 == k) || (a_1 == k) || (a_2 == k) || (a_3 == k) ||
                               (a_4 == k) || (a_5 == k) || (a_6 == k) || (a_7 == k);
                next_state = CHECK_PAIRS;
            end
            
            CHECK_PAIRS: begin
                // If k doesn't exist, result is 0
                if (!exists_k) begin
                    next_result = 1'b0;
                    next_state = FINISH;
                end else if (a_0 == k || a_1 == k || a_2 == k || a_3 == k ||
                            a_4 == k || a_5 == k || a_6 == k || a_7 == k) begin
                    // Single element equals k (already handled by exists_k, but explicit)
                    next_result = 1'b1;
                    next_state = FINISH;
                end else begin
                    // Check adjacent pairs and triplets
                    next_result = 
                        // Adjacent pairs (distance 1)
                        ( (a_0 >= k && a_1 >= k) ||
                          (a_1 >= k && a_2 >= k) ||
                          (a_2 >= k && a_3 >= k) ||
                          (a_3 >= k && a_4 >= k) ||
                          (a_4 >= k && a_5 >= k) ||
                          (a_5 >= k && a_6 >= k) ||
                          (a_6 >= k && a_7 >= k) ) ||
                        // Triplets (distance 2)
                        ( (a_0 >= k && a_2 >= k) ||
                          (a_1 >= k && a_3 >= k) ||
                          (a_2 >= k && a_4 >= k) ||
                          (a_3 >= k && a_5 >= k) ||
                          (a_4 >= k && a_6 >= k) ||
                          (a_5 >= k && a_7 >= k) );
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_done = 1'b1;
                if (!start) begin
                    next_state = IDLE;
                end
            end
            
            default: begin
                next_state = IDLE;
                next_result = 1'b0;
                next_done = 1'b0;
                next_exists_k = 1'b0;
            end
        endcase
    end

endmodule
