module BalancedParentheses #(
    parameter N = 4,
    parameter MAX_BALANCE = 16,
    parameter DATA_WIDTH = 8,
    parameter TOTAL_WIDTH = 4,
    parameter MIN_WIDTH = 4,
    parameter LEN_WIDTH = 3
)(
    input clk,
    input rst_n,
    input start,
    input [1:0] num_pieces,
    
    input [TOTAL_WIDTH-1:0] piece_total_0,
    input [TOTAL_WIDTH-1:0] piece_total_1,
    input [TOTAL_WIDTH-1:0] piece_total_2,
    input [TOTAL_WIDTH-1:0] piece_total_3,
    
    input [MIN_WIDTH-1:0] piece_min_prefix_0,
    input [MIN_WIDTH-1:0] piece_min_prefix_1,
    input [MIN_WIDTH-1:0] piece_min_prefix_2,
    input [MIN_WIDTH-1:0] piece_min_prefix_3,
    
    input [LEN_WIDTH-1:0] piece_length_0,
    input [LEN_WIDTH-1:0] piece_length_1,
    input [LEN_WIDTH-1:0] piece_length_2,
    input [LEN_WIDTH-1:0] piece_length_3,
    
    output reg [DATA_WIDTH-1:0] result,
    output reg done
);

// State declarations
localparam [2:0] S_IDLE = 3'd0;
localparam [2:0] S_INIT = 3'd1;
localparam [2:0] S_SET_PIECE = 3'd2;
localparam [2:0] S_DECIDE_ORDER = 3'd3;
localparam [2:0] S_UPDATE_LOOP = 3'd4;
localparam [2:0] S_NEXT_PIECE = 3'd5;
localparam [2:0] S_FINISH = 3'd6;

reg [2:0] state;
reg [2:0] next_state;
reg [DATA_WIDTH-1:0] dp [0:MAX_BALANCE];
reg [DATA_WIDTH-1:0] dp_next [0:MAX_BALANCE];
reg [1:0] piece_idx;
reg [TOTAL_WIDTH-1:0] cur_total;
reg [MIN_WIDTH-1:0] cur_min_prefix;
reg [LEN_WIDTH-1:0] cur_length;
reg [TOTAL_WIDTH:0] need;
reg [TOTAL_WIDTH:0] gain;
reg [MAX_BALANCE:0] bal;
reg loop_dir;
reg [MAX_BALANCE:0] loop_start;
reg [MAX_BALANCE:0] loop_end;
wire [MAX_BALANCE:0] new_bal;
reg [7:0] cycle_count;
localparam [7:0] MAX_CYCLES = 8'd100;

integer i;

assign new_bal = bal + gain;

// State register
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
            if (loop_dir == 1'b0) begin
                if (bal <= loop_end) next_state = S_NEXT_PIECE;
                else next_state = S_UPDATE_LOOP;
            end else begin
                if (bal >= loop_end) next_state = S_NEXT_PIECE;
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

// DP and main logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i <= MAX_BALANCE; i = i + 1) begin
            dp[i] <= {DATA_WIDTH{1'b1}};
        end
        dp[0] <= {DATA_WIDTH{1'b0}};
        result <= {DATA_WIDTH{1'b0}};
        done <= 1'b0;
        piece_idx <= 2'd0;
        cur_total <= {TOTAL_WIDTH{1'b0}};
        cur_min_prefix <= {MIN_WIDTH{1'b0}};
        cur_length <= {LEN_WIDTH{1'b0}};
        bal <= {MAX_BALANCE+1{1'b0}};
        loop_dir <= 1'b0;
        loop_start <= {MAX_BALANCE+1{1'b0}};
        loop_end <= {MAX_BALANCE+1{1'b0}};
        cycle_count <= 8'd0;
    end else begin
        done <= 1'b0;
        cycle_count <= cycle_count + 8'd1;
        
        case (state)
            S_IDLE: begin
                done <= 1'b0;
                cycle_count <= 8'd0;
            end
            
            S_INIT: begin
                for (i = 0; i <= MAX_BALANCE; i = i + 1) begin
                    dp[i] <= {DATA_WIDTH{1'b1}};
                end
                dp[0] <= {DATA_WIDTH{1'b0}};
                piece_idx <= 2'd0;
            end
            
            S_SET_PIECE: begin
                case (piece_idx)
                    2'd0: begin
                        cur_total <= piece_total_0;
                        cur_min_prefix <= piece_min_prefix_0;
                        cur_length <= piece_length_0;
                    end
                    2'd1: begin
                        cur_total <= piece_total_1;
                        cur_min_prefix <= piece_min_prefix_1;
                        cur_length <= piece_length_1;
                    end
                    2'd2: begin
                        cur_total <= piece_total_2;
                        cur_min_prefix <= piece_min_prefix_2;
                        cur_length <= piece_length_2;
                    end
                    2'd3: begin
                        cur_total <= piece_total_3;
                        cur_min_prefix <= piece_min_prefix_3;
                        cur_length <= piece_length_3;
                    end
                endcase
                need <= -cur_min_prefix;
                gain <= cur_total;
            end
            
            S_DECIDE_ORDER: begin
                if (gain >= 0) begin
                    loop_dir <= 1'b0;
                    loop_start <= MAX_BALANCE;
                    loop_end <= need;
                    bal <= MAX_BALANCE;
                end else begin
                    loop_dir <= 1'b1;
                    loop_start <= need;
                    loop_end <= MAX_BALANCE;
                    bal <= need;
                end
            end
            
            S_UPDATE_LOOP: begin
                if (dp[bal] != {DATA_WIDTH{1'b1}} && bal >= need && new_bal <= MAX_BALANCE) begin
                    if (dp[bal] + cur_length > dp[new_bal]) begin
                        dp[new_bal] <= dp[bal] + cur_length;
                    end
                end
                
                if (loop_dir) begin
                    bal <= bal + 1;
                end else begin
                    bal <= bal - 1;
                end
            end
            
            S_NEXT_PIECE: begin
                piece_idx <= piece_idx + 2'd1;
            end
            
            S_FINISH: begin
                result <= dp[0];
                done <= 1'b1;
            end
        endcase
    end
end

endmodule