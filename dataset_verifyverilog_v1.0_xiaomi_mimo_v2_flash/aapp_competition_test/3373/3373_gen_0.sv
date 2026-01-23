module BalancedParentheses #(
    parameter N = 4,               // Number of pieces (max 4)
    parameter MAX_BALANCE = 16,    // Maximum balance (sum of positive gains)
    parameter DATA_WIDTH = 8,      // Width for result and length
    parameter TOTAL_WIDTH = 4,     // Width for total balance (signed)
    parameter MIN_WIDTH = 4,       // Width for min_prefix (signed)
    parameter LEN_WIDTH = 3        // Width for piece length
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] num_pieces,   // Number of valid pieces (1-4)

    // Piece properties (sorted optimally: first positive pieces by need ascending,
    // then negative pieces by (need - gain) ascending)
    input wire [TOTAL_WIDTH-1:0] piece_total_0,
    input wire [TOTAL_WIDTH-1:0] piece_total_1,
    input wire [TOTAL_WIDTH-1:0] piece_total_2,
    input wire [TOTAL_WIDTH-1:0] piece_total_3,

    input wire [MIN_WIDTH-1:0] piece_min_prefix_0,
    input wire [MIN_WIDTH-1:0] piece_min_prefix_1,
    input wire [MIN_WIDTH-1:0] piece_min_prefix_2,
    input wire [MIN_WIDTH-1:0] piece_min_prefix_3,

    input wire [LEN_WIDTH-1:0] piece_length_0,
    input wire [LEN_WIDTH-1:0] piece_length_1,
    input wire [LEN_WIDTH-1:0] piece_length_2,
    input wire [LEN_WIDTH-1:0] piece_length_3,

    output reg [DATA_WIDTH-1:0] result,
    output reg done
);

// State definitions
localparam [2:0] S_IDLE        = 3'b000;
localparam [2:0] S_INIT        = 3'b001;
localparam [2:0] S_SET_PIECE   = 3'b010;
localparam [2:0] S_DECIDE_ORDER = 3'b011;
localparam [2:0] S_UPDATE_LOOP = 3'b100;
localparam [2:0] S_NEXT_PIECE  = 3'b101;
localparam [2:0] S_FINISH      = 3'b110;

reg [2:0] state, next_state;
reg [DATA_WIDTH-1:0] dp [0:MAX_BALANCE]; // DP table, index = balance
reg [DATA_WIDTH-1:0] dp_next [0:MAX_BALANCE];
reg [2:0] piece_idx; // current piece index (0 to 3)
reg signed [TOTAL_WIDTH-1:0] cur_total;
reg signed [MIN_WIDTH-1:0] cur_min_prefix;
reg [LEN_WIDTH-1:0] cur_length;
reg signed [TOTAL_WIDTH:0] need; // need = -min_prefix, positive
reg signed [TOTAL_WIDTH:0] gain; // gain = total
reg [MAX_BALANCE:0] bal; // current balance during loop
reg loop_dir; // 0: decrement, 1: increment
reg [MAX_BALANCE:0] loop_start, loop_end;
wire [MAX_BALANCE:0] new_bal;

// Helper: compute need and gain
always @(*) begin
    need = -cur_min_prefix; // cur_min_prefix is signed, so - is positive
    gain = cur_total;
end

// New balance calculation
assign new_bal = bal + gain;

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
    end else begin
        state <= next_state;
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        S_IDLE: if (start) next_state = S_INIT;
        S_INIT: next_state = S_SET_PIECE;
        S_SET_PIECE: next_state = S_DECIDE_ORDER;
        S_DECIDE_ORDER: next_state = S_UPDATE_LOOP;
        S_UPDATE_LOOP: begin
            // If loop finished, go to NEXT_PIECE
            if (loop_dir) begin
                if (bal >= loop_end) next_state = S_NEXT_PIECE;
                else next_state = S_UPDATE_LOOP;
            end else begin
                if (bal <= loop_end) next_state = S_NEXT_PIECE;
                else next_state = S_UPDATE_LOOP;
            end
        end
        S_NEXT_PIECE: begin
            if (piece_idx + 1 < num_pieces) next_state = S_SET_PIECE;
            else next_state = S_FINISH;
        end
        S_FINISH: next_state = S_IDLE;
        default: next_state = S_IDLE;
    endcase
end

// DP update logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset DP table
        for (integer i = 0; i <= MAX_BALANCE; i = i + 1) begin
            dp[i] <= {DATA_WIDTH{1'b1}}; // invalid value
        end
        dp[0] <= 0; // balance 0, length 0
        result <= 0;
        done <= 0;
        piece_idx <= 0;
        cur_total <= 0;
        cur_min_prefix <= 0;
        cur_length <= 0;
        bal <= 0;
        loop_start <= 0;
        loop_end <= 0;
        loop_dir <= 0;
    end else begin
        case (state)
            S_INIT: begin
                // Reset DP table
                for (integer i = 0; i <= MAX_BALANCE; i = i + 1) begin
                    dp[i] <= {DATA_WIDTH{1'b1}};
                end
                dp[0] <= 0;
                piece_idx <= 0;
                done <= 0;
            end

            S_SET_PIECE: begin
                // Load current piece properties
                case (piece_idx)
                    3'd0: begin
                        cur_total <= piece_total_0;
                        cur_min_prefix <= piece_min_prefix_0;
                        cur_length <= piece_length_0;
                    end
                    3'd1: begin
                        cur_total <= piece_total_1;
                        cur_min_prefix <= piece_min_prefix_1;
                        cur_length <= piece_length_1;
                    end
                    3'd2: begin
                        cur_total <= piece_total_2;
                        cur_min_prefix <= piece_min_prefix_2;
                        cur_length <= piece_length_2;
                    end
                    3'd3: begin
                        cur_total <= piece_total_3;
                        cur_min_prefix <= piece_min_prefix_3;
                        cur_length <= piece_length_3;
                    end
                endcase
            end

            S_DECIDE_ORDER: begin
                // Determine loop direction based on gain sign
                if (gain >= 0) begin
                    loop_dir <= 0; // decrement
                    loop_start <= MAX_BALANCE;
                    loop_end <= need;
                end else begin
                    loop_dir <= 1; // increment
                    loop_start <= need;
                    loop_end <= MAX_BALANCE;
                end
                bal <= loop_start;
            end

            S_UPDATE_LOOP: begin
                // For current balance bal, if dp[bal] is valid and bal >= need, update dp[new_bal]
                if (dp[bal] != {DATA_WIDTH{1'b1}} && bal >= need) begin
                    if (new_bal >= 0 && new_bal <= MAX_BALANCE) begin
                        if (dp[bal] + cur_length > dp[new_bal]) begin
                            dp[new_bal] <= dp[bal] + cur_length;
                        end
                    end
                end
                // Update bal for next iteration
                if (loop_dir) begin
                    bal <= bal + 1;
                end else begin
                    bal <= bal - 1;
                end
            end

            S_NEXT_PIECE: begin
                piece_idx <= piece_idx + 1;
            end

            S_FINISH: begin
                result <= dp[0];
                done <= 1;
            end
        endcase
    end
end

endmodule