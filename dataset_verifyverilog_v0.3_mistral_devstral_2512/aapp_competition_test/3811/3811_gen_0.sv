module wcd_finder #(
    parameter MAX_PAIRS = 8,
    parameter DATA_WIDTH = 32,
    parameter MAX_CANDIDATES = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] a_in,
    input wire [DATA_WIDTH-1:0] b_in,
    input wire [2:0] pair_count,
    output reg [DATA_WIDTH-1:0] wcd_result,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] FACTOR_CHECK = 3'd1;
    localparam [2:0] FACTOR_UPDATE = 3'd2;
    localparam [2:0] RESULT_READY = 3'd3;

    // Internal registers
    reg [DATA_WIDTH-1:0] candidates [0:MAX_CANDIDATES-1];
    reg [2:0] state, next_state;
    reg [2:0] pair_idx;
    reg [2:0] candidate_idx;
    reg [2:0] valid_count;
    reg [DATA_WIDTH-1:0] stored_a, stored_b;
    reg [DATA_WIDTH-1:0] temp_result;
    
    // Helper wires for divisibility checks
    wire candidate_divides_a = (stored_a % candidates[candidate_idx] == 0);
    wire candidate_divides_b = (stored_b % candidates[candidate_idx] == 0);
    wire is_valid_candidate = candidate_divides_a || candidate_divides_b;

    integer i;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pair_idx <= 0;
            candidate_idx <= 0;
            valid_count <= 0;
            done <= 1'b0;
            valid <= 1'b0;
            wcd_result <= 32'd0;
            stored_a <= 32'd0;
            stored_b <= 32'd0;
            temp_result <= 32'd0;
            for (i = 0; i < MAX_CANDIDATES; i = i + 1) begin
                candidates[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        pair_idx <= 0;
                        candidate_idx <= 0;
                        valid_count <= 0;
                        stored_a <= a_in;
                        stored_b <= b_in;
                        // Initialize candidates with simple divisors
                        candidates[0] <= (a_in > 1) ? a_in : 32'd2;
                        candidates[1] <= (b_in > 1) ? b_in : 32'd3;
                        candidates[2] <= 32'd5;
                        candidates[3] <= 32'd7;
                        candidates[4] <= 32'd11;
                        candidates[5] <= 32'd13;
                        candidates[6] <= 32'd17;
                        candidates[7] <= 32'd19;
                        valid_count <= 2;
                    end
                end
                
                FACTOR_CHECK: begin
                    // Check if current candidate works for current pair
                    if (!is_valid_candidate) begin
                        // Mark as invalid by setting to 0
                        candidates[candidate_idx] <= 32'd0;
                        valid_count <= (valid_count > 0) ? valid_count - 1 : 0;
                    end
                    candidate_idx <= candidate_idx + 1;
                end
                
                FACTOR_UPDATE: begin
                    // Get next pair
                    if (pair_idx < pair_count) begin
                        stored_a <= a_in;
                        stored_b <= b_in;
                        candidate_idx <= 0;
                        pair_idx <= pair_idx + 1;
                    end
                end
                
                RESULT_READY: begin
                    // Find first valid candidate
                    if (candidates[candidate_idx] > 1 && valid_count > 0) begin
                        wcd_result <= candidates[candidate_idx];
                        valid <= 1'b1;
                    end else begin
                        valid <= 1'b0;
                    end
                    done <= 1'b1;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = FACTOR_CHECK;
            end
            
            FACTOR_CHECK: begin
                if (candidate_idx >= MAX_CANDIDATES - 1) begin
                    if (pair_idx < pair_count - 1) begin
                        next_state = FACTOR_UPDATE;
                    end else begin
                        next_state = RESULT_READY;
                    end
                end else begin
                    next_state = FACTOR_CHECK;
                end
            end
            
            FACTOR_UPDATE: begin
                next_state = FACTOR_CHECK;
            end
            
            RESULT_READY: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule