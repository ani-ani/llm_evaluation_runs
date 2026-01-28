module crate_rearrangement #(
    parameter N = 8,              // Number of stacks (max 8 for hardware)
    parameter HEIGHT_BITS = 8,    // Bits per stack height (0-255)
    parameter ACTION_BITS = 16,   // Bits for action count
    parameter K_MAX = 8           // Maximum new stacks to try
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [HEIGHT_BITS-1:0] stacks [0:N-1],
    output reg [ACTION_BITS-1:0] min_actions,
    output reg done
);

    // State machine states
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] COMPUTE_TOTAL  = 3'd1;
    localparam [2:0] TRY_K          = 3'd2;
    localparam [2:0] CALCULATE_MOVES = 3'd3;
    localparam [2:0] UPDATE_MIN     = 3'd4;
    localparam [2:0] FINISHED       = 3'd5;

    reg [2:0] state;
    reg [2:0] next_state;
    
    // Internal registers
    reg [31:0] total;           // Sum of all stacks
    reg [31:0] current_total;   // Accumulator for sum
    reg [7:0] k;                // Current K value
    reg [31:0] target;          // Target height per stack
    reg [31:0] moves;           // Moves for current K
    reg [31:0] prefix_sum;      // Cumulative excess/deficit
    reg [31:0] min_moves;       // Minimum moves found
    reg [4:0] index;            // Index for iteration
    reg signed [31:0] diff;     // Difference at current stack (signed)
    reg [31:0] temp_moves;      // Temporary moves calculation
    reg [31:0] abs_prefix;      // Absolute value of prefix sum
    
    // Combinational logic for next state
    always @(*) begin
        case (state)
            IDLE: next_state = start ? COMPUTE_TOTAL : IDLE;
            COMPUTE_TOTAL: next_state = (index == N) ? TRY_K : COMPUTE_TOTAL;
            TRY_K: begin
                if (k > K_MAX) 
                    next_state = FINISHED;
                else if (total % (N + k) == 0) 
                    next_state = CALCULATE_MOVES;
                else 
                    next_state = TRY_K;
            end
            CALCULATE_MOVES: next_state = (index >= m) ? UPDATE_MIN : CALCULATE_MOVES;
            UPDATE_MIN: next_state = TRY_K;
            FINISHED: next_state = FINISHED;
            default: next_state = IDLE;
        endcase
    end

    // Sequential state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Main logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total <= 32'd0;
            current_total <= 32'd0;
            k <= 8'd0;
            target <= 32'd0;
            moves <= 32'd0;
            prefix_sum <= 32'd0;
            min_moves <= 32'hFFFFFFFF;
            index <= 5'd0;
            diff <= 32'd0;
            done <= 1'b0;
            min_actions <= 16'd0;
            temp_moves <= 32'd0;
            abs_prefix <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    min_moves <= 32'hFFFFFFFF;
                    current_total <= 32'd0;
                    index <= 5'd0;
                end
                
                COMPUTE_TOTAL: begin
                    if (index < N) begin
                        current_total <= current_total + stacks[index];
                        index <= index + 1;
                    end else begin
                        total <= current_total;
                        current_total <= 32'd0;
                        index <= 5'd0;
                        k <= 8'd0;
                    end
                end
                
                TRY_K: begin
                    if (k <= K_MAX) begin
                        if (total % (N + k) == 0) begin
                            target <= total / (N + k);
                            index <= 5'd0;
                            prefix_sum <= 32'd0;
                            moves <= 32'd0;
                        end else begin
                            k <= k + 8'd1;
                        end
                    end else begin
                        // Finished all K values
                        min_actions <= min_moves[15:0];
                        done <= 1'b1;
                    end
                end
                
                CALCULATE_MOVES: begin
                    if (index < (N + k)) begin
                        // Get stack height (0 for new stacks beyond N)
                        if (index < N) begin
                            diff <= stacks[index] - target;
                        end else begin
                            diff <= 32'd0 - target;
                        end
                        
                        // Update prefix sum
                        prefix_sum <= prefix_sum + diff;
                        
                        // Compute absolute prefix for this iteration
                        if ((prefix_sum + diff) > 32'h7FFFFFFF) begin
                            abs_prefix <= ~(prefix_sum + diff) + 32'd1;
                        end else begin
                            abs_prefix <= prefix_sum + diff;
                        end
                        
                        // Accumulate moves: 2 * excess + |prefix_sum|
                        if (diff > 0) begin
                            temp_moves <= (diff << 1) + abs_prefix;
                        end else begin
                            temp_moves <= abs_prefix;
                        end
                        
                        moves <= moves + temp_moves;
                        index <= index + 1;
                    end else begin
                        // Loop complete
                    end
                end
                
                UPDATE_MIN: begin
                    if (moves < min_moves) begin
                        min_moves <= moves;
                    end
                    k <= k + 8'd1;
                end
                
                FINISHED: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule