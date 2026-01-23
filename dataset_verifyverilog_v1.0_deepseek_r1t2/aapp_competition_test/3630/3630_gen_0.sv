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

// Internal registers
reg [7:0] prev_pos, prev_neg;
reg [15:0] acc;
reg [$clog2(N+1)-1:0] idx;
reg processing;

// State encoding
localparam IDLE = 1'b0;
localparam PROCESSING = 1'b1;

// Combinational helpers
wire [7:0] diff = s2[idx] - s1[idx];
wire [7:0] pos = (s2[idx] > s1[idx]) ? diff : 8'd0;
wire [7:0] neg = (s1[idx] > s2[idx]) ? (s1[idx] - s2[idx]) : 8'd0;
wire [7:0] inc_pos = (pos > prev_pos) ? (pos - prev_pos) : 8'd0;
wire [7:0] inc_neg = (neg > prev_neg) ? (neg - prev_neg) : 8'd0;

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        done <= 1'b0;
        result <= 16'd0;
        acc <= 16'd0;
        prev_pos <= 8'd0;
        prev_neg <= 8'd0;
        idx <= N;
        processing <= IDLE;
    end else begin
        case (processing)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    processing <= PROCESSING;
                    idx <= 0;
                    acc <= 16'd0;
                    prev_pos <= 8'd0;
                    prev_neg <= 8'd0;
                end
            end
            PROCESSING: begin
                acc <= acc + inc_pos + inc_neg;
                prev_pos <= pos;
                prev_neg <= neg;
                idx <= idx + 1;
                if (idx == N-1) begin
                    processing <= IDLE;
                    result <= acc + inc_pos + inc_neg;
                    done <= 1'b1;
                end
            end
            default: processing <= IDLE;
        endcase
    end
end

endmodule