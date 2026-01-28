module string_puzzle_solver #(
    parameter N = 16
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] s1 [0:N-1],
    input wire [7:0] s2 [0:N-1],
    output reg [15:0] result,
    output reg done
);

// State declarations
localparam [1:0] IDLE       = 2'd0;
localparam [1:0] PROCESSING = 2'd1;
localparam [1:0] FINISH     = 2'd2;

// Internal registers
reg [1:0] state, next_state;
reg [7:0] prev_pos, prev_neg;
reg [15:0] acc;
reg [$clog2(N+1)-1:0] idx;
reg [7:0] idx_reg;
reg [7:0] inc_pos_reg, inc_neg_reg;

// Combinational logic
reg [7:0] diff;
reg [7:0] pos;
reg [7:0] neg;
reg [7:0] inc_pos;
reg [7:0] inc_neg;

always @(*) begin
    diff = s2[idx_reg] - s1[idx_reg];
    pos = (s2[idx_reg] > s1[idx_reg]) ? diff : 8'd0;
    neg = (s1[idx_reg] > s2[idx_reg]) ? (s1[idx_reg] - s2[idx_reg]) : 8'd0;
    inc_pos = (pos > prev_pos) ? (pos - prev_pos) : 8'd0;
    inc_neg = (neg > prev_neg) ? (neg - prev_neg) : 8'd0;
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 16'd0;
        done <= 1'b0;
        acc <= 16'd0;
        prev_pos <= 8'd0;
        prev_neg <= 8'd0;
        idx_reg <= 8'd0;
        idx <= N;
        inc_pos_reg <= 8'd0;
        inc_neg_reg <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= PROCESSING;
                    idx <= 0;
                    idx_reg <= 8'd0;
                    acc <= 16'd0;
                    prev_pos <= 8'd0;
                    prev_neg <= 8'd0;
                    inc_pos_reg <= 8'd0;
                    inc_neg_reg <= 8'd0;
                end
            end
            PROCESSING: begin
                inc_pos_reg <= inc_pos;
                inc_neg_reg <= inc_neg;
                prev_pos <= pos;
                prev_neg <= neg;
                idx <= idx + 1;
                idx_reg <= idx_reg + 8'd1;
                
                if (idx_reg == N-1) begin
                    state <= FINISH;
                    acc <= acc + inc_pos + inc_neg;
                end else begin
                    acc <= acc + inc_pos + inc_neg;
                end
            end
            FINISH: begin
                result <= acc + inc_pos_reg + inc_neg_reg;
                done <= 1'b1;
                state <= IDLE;
            end
            default: state <= IDLE;
        endcase
    end
end

endmodule