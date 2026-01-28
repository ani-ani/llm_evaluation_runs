module find_crash_line #(
    parameter MAX_N = 256,
    parameter N_WIDTH = 8,
    parameter R_WIDTH = 32,
    parameter P_WIDTH = 32,
    parameter RESULT_WIDTH = 64
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [N_WIDTH-1:0] n,
    input wire [R_WIDTH-1:0] r,
    input wire [P_WIDTH-1:0] p,
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

// State encoding
localparam [1:0] IDLE = 2'd0;
localparam [1:0] COMPUTE_M = 2'd1;
localparam [1:0] COMPUTE_S = 2'd2;
localparam [1:0] DONE_STATE = 2'd3;

reg [1:0] state;
reg [N_WIDTH-1:0] m;
reg [N_WIDTH-1:0] s;
reg [RESULT_WIDTH-1:0] best;
reg [RESULT_WIDTH-1:0] f [1:MAX_N];
integer i;

// Combinational signals
wire [N_WIDTH-1:0] k;
wire [RESULT_WIDTH-1:0] mult;
wire [RESULT_WIDTH-1:0] f_k;
wire [RESULT_WIDTH-1:0] cost;

assign k = (m + s - 1) / s;
assign mult = (s - 1) * p;
assign f_k = f[k];
assign cost = mult + r + f_k;

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= {RESULT_WIDTH{1'b0}};
        m <= {N_WIDTH{1'b0}};
        s <= {N_WIDTH{1'b0}};
        best <= {RESULT_WIDTH{1'b0}};
        for (i = 1; i <= MAX_N; i = i + 1) begin
            f[i] <= {RESULT_WIDTH{1'b0}};
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    f[1] <= {RESULT_WIDTH{1'b0}};
                    m <= 8'd2;
                    state <= COMPUTE_M;
                end
            end

            COMPUTE_M: begin
                if (m > n) begin
                    result <= f[n];
                    done <= 1'b1;
                    state <= DONE_STATE;
                end else begin
                    best <= {RESULT_WIDTH{1'b1}};
                    s <= 8'd2;
                    state <= COMPUTE_S;
                end
            end

            COMPUTE_S: begin
                if (s > m) begin
                    f[m] <= best;
                    m <= m + 8'd1;
                    state <= COMPUTE_M;
                end else begin
                    if (cost < best) begin
                        best <= cost;
                    end
                    s <= s + 8'd1;
                end
            end

            DONE_STATE: begin
                // stay in DONE_STATE
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule