module wcd_finder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] a_in,
    input wire [31:0] b_in,
    input wire [2:0] pair_count,
    output reg [31:0] wcd_result,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] STORE_PAIR = 3'd1;
    localparam [2:0] CHECK_CANDIDATE = 3'd2;
    localparam [2:0] NEXT_CANDIDATE = 3'd3;
    localparam [2:0] NEXT_PAIR = 3'd4;
    localparam [2:0] FIND_RESULT = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    // Internal registers
    reg [2:0] state, next_state;
    reg [2:0] pair_idx;
    reg [2:0] candidate_idx;
    reg [2:0] valid_count;
    reg [31:0] stored_a, stored_b;
    reg [31:0] candidates [0:7];
    reg found_valid;
    reg [31:0] result_temp;
    integer i;

    // Helper wires for division checks
    wire candidate_divides_a = (stored_a % candidates[candidate_idx] == 0);
    wire candidate_divides_b = (stored_b % candidates[candidate_idx] == 0);
    wire is_valid = candidate_divides_a || candidate_divides_b;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pair_idx <= 3'd0;
            candidate_idx <= 3'd0;
            valid_count <= 3'd0;
            stored_a <= 32'd0;
            stored_b <= 32'd0;
            wcd_result <= 32'd0;
            done <= 1'b0;
            valid <= 1'b0;
            found_valid <= 1'b0;
            result_temp <= 32'd0;
            for (i = 0; i < 8; i = i + 1) begin
                candidates[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    pair_idx <= 3'd0;
                    candidate_idx <= 3'd0;
                    valid_count <= 3'd0;
                    found_valid <= 1'b0;
                    result_temp <= 32'd0;
                    if (start) begin
                        stored_a <= a_in;
                        stored_b <= b_in;
                        // Initialize candidates with first pair values and defaults
                        candidates[0] <= a_in;
                        candidates[1] <= b_in;
                        candidates[2] <= 32'd2;
                        candidates[3] <= 32'd3;
                        candidates[4] <= 32'd5;
                        candidates[5] <= 32'd7;
                        candidates[6] <= 32'd11;
                        candidates[7] <= 32'd13;
                        valid_count <= 3'd2; // First two are from initial pair
                    end
                end
                
                STORE_PAIR: begin
                    stored_a <= a_in;
                    stored_b <= b_in;
                    candidate_idx <= 3'd0;
                end
                
                CHECK_CANDIDATE: begin
                    // Check if current candidate is still valid
                    if (candidate_idx < valid_count) begin
                        if (!is_valid) begin
                            // Mark as invalid by setting to 0
                            candidates[candidate_idx] <= 32'd0;
                            valid_count <= (valid_count > 0) ? valid_count - 1 : 0;
                        end
                    end
                end
                
                NEXT_CANDIDATE: begin
                    // Increment candidate index for next check
                    candidate_idx <= candidate_idx + 1;
                end
                
                NEXT_PAIR: begin
                    pair_idx <= pair_idx + 1;
                    stored_a <= a_in;
                    stored_b <= b_in;
                    candidate_idx <= 3'd0;
                end
                
                FIND_RESULT: begin
                    // Find first valid candidate
                    if (candidate_idx < 8 && candidates[candidate_idx] > 1 && 
                        !found_valid && valid_count > 0) begin
                        result_temp <= candidates[candidate_idx];
                        found_valid <= 1'b1;
                    end
                    candidate_idx <= candidate_idx + 1;
                end
                
                DONE_STATE: begin
                    wcd_result <= result_temp;
                    valid <= found_valid;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = STORE_PAIR;
                end
            end
            
            STORE_PAIR: begin
                next_state = CHECK_CANDIDATE;
            end
            
            CHECK_CANDIDATE: begin
                next_state = NEXT_CANDIDATE;
            end
            
            NEXT_CANDIDATE: begin
                if (candidate_idx >= 8'd7 || candidate_idx >= valid_count) begin
                    if (pair_idx < pair_count - 1) begin
                        next_state = NEXT_PAIR;
                    end else begin
                        next_state = FIND_RESULT;
                    end
                end else begin
                    next_state = CHECK_CANDIDATE;
                end
            end
            
            NEXT_PAIR: begin
                next_state = CHECK_CANDIDATE;
            end
            
            FIND_RESULT: begin
                if (candidate_idx >= 8'd8 || found_valid) begin
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule