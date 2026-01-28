module alternating_chain_solver #(
    parameter N = 8,                // Number of comments (max 8)
    parameter DATA_WIDTH = 16,      // Width for scores, c, r
    parameter RESULT_WIDTH = 32     // Width for result
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [DATA_WIDTH-1:0] s [0:N-1],  // Scores
    input wire [DATA_WIDTH-1:0] c,                 // Account creation time
    input wire [DATA_WIDTH-1:0] r,                 // Report time
    output reg [RESULT_WIDTH-1:0] result,          // Minimum total time
    output reg done
);

// State machine declarations
localparam [3:0] IDLE        = 4'd0;
localparam [3:0] INIT        = 4'd1;
localparam [3:0] LOOP_MASK   = 4'd2;
localparam [3:0] LOOP_SIGN   = 4'd3;
localparam [3:0] PROC_COMMENT = 4'd4;
localparam [3:0] COMPUTE_COST = 4'd5;
localparam [3:0] UPDATE_MIN = 4'd6;
localparam [3:0] FINISH     = 4'd7;

reg [3:0] state, next_state;
reg [N-1:0] mask;                   // Current subset mask
reg start_sign;                     // Current start sign (0:+, 1:-)
reg [RESULT_WIDTH-1:0] min_cost;    // Minimum cost found

// Processing counters/registers
reg [3:0] idx;                      // Comment index
reg signed [RESULT_WIDTH-1:0] current_cost;
reg signed [RESULT_WIDTH-1:0] removal_cost;
reg signed [RESULT_WIDTH-1:0] voting_cost;
reg [RESULT_WIDTH-1:0] upvotes, downvotes;
reg [7:0] kept_count;

// Overflow prevention counter
reg [15:0] cycle_count;
localparam [15:0] MAX_CYCLES = 16'd32768;

// Temporary calculation signals
reg desired_sign;                      // Desired sign for current comment
reg sign_alternate;                    // Tracks sign alternation
wire [RESULT_WIDTH-1:0] upvotes_temp, downvotes_temp;
wire [RESULT_WIDTH-1:0] max_vote_cost;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= {RESULT_WIDTH{1'b0}};
        done <= 1'b0;
        mask <= {N{1'b0}};
        start_sign <= 1'b0;
        min_cost <= {RESULT_WIDTH{1'b1}}; // Initialize to max value
        idx <= 4'd0;
        cycle_count <= 16'd0;
    end else begin
        cycle_count <= cycle_count + 16'd1;
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= INIT;
                    min_cost <= {RESULT_WIDTH{1'b1}}; // Reset min cost
                end
            end
            
            INIT: begin
                mask <= {N{1'b0}};
                start_sign <= 1'b0;
                idx <= 4'd0;
                upvotes <= 32'd0;
                downvotes <= 32'd0;
                kept_count <= 8'd0;
                removal_cost <= 32'd0;
                voting_cost <= 32'd0;
                current_cost <= 32'd0;
                state <= LOOP_MASK;
            end
            
            LOOP_MASK: begin
                upvotes <= 32'd0;
                downvotes <= 32'd0;
                kept_count <= 8'd0;
                idx <= 4'd0;
                start_sign <= 1'b0;
                if (mask == {N{1'b1}}) begin
                    state <= FINISH;
                end else begin
                    state <= LOOP_SIGN;
                end
            end
            
            LOOP_SIGN: begin
                idx <= 4'd0;
                sign_alternate <= start_sign;
                state <= PROC_COMMENT;
            end
            
            PROC_COMMENT: begin
                if (idx == N) begin
                    state <= COMPUTE_COST;
                end else begin
                    if (mask[idx]) begin // Include this comment
                        kept_count <= kept_count + 8'd1;
                        desired_sign = sign_alternate;
                        
                        // Calculate vote requirements
                        if (desired_sign == 1'b1) begin // Should be negative
                            if ($signed(s[idx]) >= 0) begin
                                downvotes <= downvotes + (s[idx] + 1);
                            end
                        end else begin // Should be positive
                            if ($signed(s[idx]) <= 0) begin
                                upvotes <= upvotes + (1 - s[idx]);
                            end
                        end
                        
                        sign_alternate <= ~sign_alternate;
                    end
                    idx <= idx + 4'd1;
                end
            end
            
            COMPUTE_COST: begin
                removal_cost <= r * (N - kept_count);
                max_vote_cost = (upvotes > downvotes) ? upvotes : downvotes;
                voting_cost <= c * max_vote_cost;
                current_cost <= removal_cost + voting_cost;
                state <= UPDATE_MIN;
            end
            
            UPDATE_MIN: begin
                if (current_cost < min_cost) begin
                    min_cost <= current_cost;
                end
                
                // Move to next sign state
                if (start_sign) begin
                    start_sign <= 1'b0;
                    mask <= mask + {{(N-1){1'b0}}, 1'b1};
                    state <= LOOP_MASK;
                end else begin
                    start_sign <= 1'b1;
                    state <= LOOP_SIGN;
                end
            end
            
            FINISH: begin
                result <= min_cost;
                done <= 1'b1;
                if (!start) state <= IDLE;
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
        
        // Timeout protection
        if (cycle_count >= MAX_CYCLES) begin
            state <= FINISH;
            done <= 1'b1;
            result <= min_cost;
        end
    end
end

endmodule