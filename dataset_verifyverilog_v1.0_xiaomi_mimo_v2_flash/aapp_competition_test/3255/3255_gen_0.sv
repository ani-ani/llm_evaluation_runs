module hopper_exploration (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,       // Number of valid elements (1-8)
    input [2:0] D,       // Maximum jump distance (1-7)
    input [7:0] M,       // Maximum value difference (0-255, signed)
    input [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7, // Array elements (8-bit signed)
    output reg [3:0] length, // Longest sequence length (1-8)
    output reg done           // Computation complete
);

// State definitions
localparam [1:0] STATE_IDLE = 2'd0;
localparam [1:0] STATE_INIT = 2'd1;
localparam [1:0] STATE_COMPUTE = 2'd2;
localparam [1:0] STATE_DONE = 2'd3;

// Registers
reg [1:0] state, next_state;
reg [2:0] i, j;              // Loop counters
reg [7:0] dp [0:255];        // DP table: 256 states, max length 8 (stored as 8-bit)
reg [7:0] max_len_reg;
reg [7:0] arr_reg [0:7];     // Local storage for array
reg [2:0] n_reg, D_reg;      // Local storage for parameters
reg [7:0] M_reg;
reg [7:0] dp_index;
reg [7:0] dp_prev_index;

// Combinational signals
wire signed [7:0] arr_val_i;
wire signed [7:0] arr_val_j;
wire signed [7:0] diff;
wire [7:0] diff_abs;
wire valid_jump;

// Assign array values
assign arr_val_i = arr_reg[i];
assign arr_val_j = arr_reg[j];
assign diff = arr_val_i - arr_val_j;
assign diff_abs = diff[7] ? (~diff + 8'd1) : diff;

// Check valid jump condition
// j must be different from i, within D distance, and value diff within M
assign valid_jump = (j < n_reg) && (j != i) && (diff_abs <= M_reg) && 
                    ($signed(i) >= $signed(j)) && (($signed(i) - $signed(j)) <= $signed(D_reg));

// State transition logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= STATE_IDLE;
    end else begin
        state <= next_state;
    end
end

always @(*) begin
    next_state = state;
    case (state)
        STATE_IDLE: if (start) next_state = STATE_INIT;
        STATE_INIT: next_state = STATE_COMPUTE;
        STATE_COMPUTE: begin
            if (i >= n_reg) next_state = STATE_DONE;
            else next_state = STATE_COMPUTE;
        end
        STATE_DONE: next_state = STATE_IDLE;
        default: next_state = STATE_IDLE;
    endcase
end

// Main computation logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers
        i <= 3'd0;
        j <= 3'd0;
        max_len_reg <= 8'd0;
        done <= 1'b0;
        length <= 4'd0;
        dp_index <= 8'd0;
        dp_prev_index <= 8'd0;
        // Clear dp table
        for (integer k = 0; k < 256; k = k + 1) begin
            dp[k] <= 8'd0;
        end
        // Clear arr_reg
        for (integer k = 0; k < 8; k = k + 1) begin
            arr_reg[k] <= 8'd0;
        end
        n_reg <= 3'd0;
        D_reg <= 3'd0;
        M_reg <= 8'd0;
    end else begin
        case (state)
            STATE_IDLE: begin
                done <= 1'b0;
                i <= 3'd0;
                j <= 3'd0;
            end
            
            STATE_INIT: begin
                // Load inputs into local registers
                arr_reg[0] <= arr_0;
                arr_reg[1] <= arr_1;
                arr_reg[2] <= arr_2;
                arr_reg[3] <= arr_3;
                arr_reg[4] <= arr_4;
                arr_reg[5] <= arr_5;
                arr_reg[6] <= arr_6;
                arr_reg[7] <= arr_7;
                n_reg <= n;
                D_reg <= D;
                M_reg <= M;
                
                // Initialize DP table for single-element sequences
                // dp[mask] where mask has only bit k set = 1
                for (integer k = 0; k < 8; k = k + 1) begin
                    if (k < n) begin
                        dp[1 << k] <= 8'd1;
                    end else begin
                        dp[1 << k] <= 8'd0;
                    end
                end
                
                i <= 3'd0;
                j <= 3'd0;
                max_len_reg <= 8'd1; // Minimum length is 1
            end
            
            STATE_COMPUTE: begin
                if (i < n_reg) begin
                    if (j < n_reg) begin
                        // Check if j is reachable from i (and i != j)
                        if (valid_jump) begin
                            // Calculate indices
                            dp_prev_index <= (1 << i);
                            dp_index <= (1 << i) | (1 << j);
                            
                            // Update DP state if better path found
                            // dp[new_mask][j] = max(dp[new_mask][j], dp[1<<i][i] + 1)
                            if (dp[(1 << i) | (1 << j)] < dp[1 << i] + 8'd1) begin
                                dp[(1 << i) | (1 << j)] <= dp[1 << i] + 8'd1;
                                if (dp[1 << i] + 8'd1 > max_len_reg) begin
                                    max_len_reg <= dp[1 << i] + 8'd1;
                                end
                            end
                        end
                        j <= j + 3'd1;
                    end else begin
                        j <= 3'd0;
                        i <= i + 3'd1;
                    end
                end
            end
            
            STATE_DONE: begin
                done <= 1'b1;
                length <= max_len_reg[3:0]; // Truncate to 4 bits (max 8)
            end
            
            default: begin
                state <= STATE_IDLE;
                done <= 1'b0;
                length <= 4'd0;
            end
        endcase
    end
end

endmodule