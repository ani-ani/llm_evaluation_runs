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

    // State declarations with explicit widths
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] COMPUTE_TOTAL = 3'd1;
    localparam [2:0] TRY_K        = 3'd2;
    localparam [2:0] CALCULATE_MOVES = 3'd3;
    localparam [2:0] UPDATE_MIN   = 3'd4;
    localparam [2:0] FINISHED     = 3'd5;
    
    reg [2:0] state, next_state;
    
    // Internal registers
    reg [31:0] total;
    reg [31:0] current_total;
    reg [7:0] k;
    reg [7:0] m;
    reg [31:0] target;
    reg [31:0] moves;
    reg signed [31:0] prefix_sum;
    reg [31:0] sum_excess;
    reg [ACTION_BITS-1:0] min_moves;
    reg [4:0] index;
    reg signed [31:0] diff;
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? COMPUTE_TOTAL : IDLE;
            COMPUTE_TOTAL: next_state = (index == 5'd0) ? TRY_K : COMPUTE_TOTAL;
            TRY_K: begin
                if (k > K_MAX) 
                    next_state = FINISHED;
                else if ((total % (N + k)) == 32'd0) 
                    next_state = CALCULATE_MOVES;
                else 
                    next_state = TRY_K;
            end
            CALCULATE_MOVES: next_state = (index == m) ? UPDATE_MIN : CALCULATE_MOVES;
            UPDATE_MIN: next_state = TRY_K;
            FINISHED: next_state = FINISHED;
            default: next_state = IDLE;
        endcase
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            total <= 32'd0;
            current_total <= 32'd0;
            k <= 8'd0;
            m <= 8'd0;
            target <= 32'd0;
            moves <= 32'd0;
            prefix_sum <= 32'd0;
            sum_excess <= 32'd0;
            min_moves <= {ACTION_BITS{1'b1}};
            index <= 5'd0;
            diff <= 32'd0;
            done <= 1'b0;
            min_actions <= {ACTION_BITS{1'b0}};
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    current_total <= 32'd0;
                    min_moves <= {ACTION_BITS{1'b1}};
                    index <= 5'd0;
                end
                
                COMPUTE_TOTAL: begin
                    if (index < 5'd8) begin
                        current_total <= current_total + stacks[index];
                        index <= index + 5'd1;
                    end else if (index == 5'd8) begin
                        total <= current_total;
                        index <= 5'd0;
                        k <= 8'd0;
                    end
                end
                
                TRY_K: begin
                    if (k > K_MAX) begin
                        state <= FINISHED;
                        min_actions <= min_moves;
                        done <= 1'b1;
                    end else begin
                        if ((total % (N + k)) == 32'd0) begin
                            m <= N + k;
                            target <= total / (N + k);
                            index <= 5'd0;
                            prefix_sum <= 32'd0;
                            sum_excess <= 32'd0;
                            moves <= 32'd0;
                        end else begin
                            k <= k + 8'd1;
                        end
                    end
                end
                
                CALCULATE_MOVES: begin
                    if (index < m) begin
                        // Get stack value or treat as 0 for new stacks
                        diff <= (index < 5'd8) ? (32'(stacks[index]) - target) : (32'd0 - target);
                        
                        prefix_sum <= prefix_sum + diff;
                        
                        // Accumulate positive excess
                        sum_excess <= sum_excess + ((diff > 0) ? diff : 32'd0);
                        
                        index <= index + 5'd1;
                    end else begin
                        // Final calculation after all elements processed
                        moves <= (sum_excess << 1); // 2*sum_excess
                        k <= k + 8'd1;
                    end
                end
                
                UPDATE_MIN: begin
                    if (moves < min_moves) begin
                        min_moves <= moves;
                    end
                end
                
                FINISHED: begin
                    done <= 1'b1;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
endmodule