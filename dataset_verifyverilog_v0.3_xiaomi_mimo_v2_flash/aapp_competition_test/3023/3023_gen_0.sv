module cake_divider #(
    parameter N = 8,
    parameter M = 4
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] x_candles [0:N-1],
    input wire signed [15:0] y_candles [0:N-1],
    input wire signed [31:0] a_lines [0:M-1],
    input wire signed [31:0] b_lines [0:M-1],
    input wire signed [31:0] c_lines [0:M-1],
    input wire [7:0] n,
    input wire [7:0] m,
    input wire signed [15:0] r,
    output reg done,
    output reg result
);

// State definitions
localparam [4:0] IDLE = 5'd0;
localparam [4:0] INIT_PAIR = 5'd1;
localparam [4:0] COMPUTE_DET = 5'd2;
localparam [4:0] CHECK_DET = 5'd3;
localparam [4:0] COMPUTE_DXDY = 5'd4;
localparam [4:0] SQUARE = 5'd5;
localparam [4:0] COMPARE = 5'd6;
localparam [4:0] NEXT_PAIR = 5'd7;
localparam [4:0] CHECK_F = 5'd8;
localparam [4:0] COMPARE_F = 5'd9;
localparam [4:0] INIT_SIG = 5'd10;
localparam [4:0] COMPUTE_SIG = 5'd11;
localparam [4:0] NEXT_CANDLE = 5'd12;
localparam [4:0] CHECK_DUP = 5'd13;
localparam [4:0] DONE = 5'd14;

reg [4:0] state;
reg [7:0] i, j;
reg [7:0] k;
reg [7:0] l;
reg signed [63:0] det;
reg signed [63:0] dx, dy;
reg signed [63:0] lhs, rhs;
reg [15:0] I;
reg [15:0] F;
reg [M-1:0] signatures [0:N-1];
reg [M-1:0] current_sig;
reg duplicate_found;

reg signed [31:0] a_i_reg, b_i_reg, c_i_reg;
reg signed [31:0] a_j_reg, b_j_reg, c_j_reg;

reg duplicate_found_wire;

always @(*) begin
    duplicate_found_wire = 1'b0;
    for (integer idx_i = 0; idx_i < N; idx_i = idx_i + 1) begin
        for (integer idx_j = idx_i + 1; idx_j < N; idx_j = idx_j + 1) begin
            if (idx_i < n && idx_j < n && signatures[idx_i] == signatures[idx_j]) begin
                duplicate_found_wire = 1'b1;
            end
        end
    end
end

wire signed [63:0] val_current;
wire signed [63:0] temp_mult1;
wire signed [63:0] temp_mult2;
wire signed [63:0] temp_mult3;
assign temp_mult1 = $signed(a_lines[l]) * $signed(x_candles[k]);
assign temp_mult2 = $signed(b_lines[l]) * $signed(y_candles[k]);
assign temp_mult3 = $signed(c_lines[l]);
assign val_current = temp_mult1 + temp_mult2 + temp_mult3;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 1'b0;
        I <= 16'd0;
        F <= 16'd0;
        i <= 8'd0;
        j <= 8'd0;
        k <= 8'd0;
        l <= 8'd0;
        duplicate_found <= 1'b0;
        for (integer idx = 0; idx < N; idx = idx + 1) begin
            signatures[idx] <= {M{1'b0}};
        end
        current_sig <= {M{1'b0}};
        a_i_reg <= 32'd0;
        b_i_reg <= 32'd0;
        c_i_reg <= 32'd0;
        a_j_reg <= 32'd0;
        b_j_reg <= 32'd0;
        c_j_reg <= 32'd0;
        det <= 64'd0;
        dx <= 64'd0;
        dy <= 64'd0;
        lhs <= 64'd0;
        rhs <= 64'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= INIT_PAIR;
                    I <= 16'd0;
                    i <= 8'd0;
                    j <= 8'd1;
                end
            end
            INIT_PAIR: begin
                a_i_reg <= a_lines[i];
                b_i_reg <= b_lines[i];
                c_i_reg <= c_lines[i];
                a_j_reg <= a_lines[j];
                b_j_reg <= b_lines[j];
                c_j_reg <= c_lines[j];
                state <= COMPUTE_DET;
            end
            COMPUTE_DET: begin
                det <= $signed(a_i_reg) * $signed(b_j_reg) - $signed(a_j_reg) * $signed(b_i_reg);
                state <= CHECK_DET;
            end
            CHECK_DET: begin
                if (det == 64'sd0) begin
                    state <= NEXT_PAIR;
                end else begin
                    state <= COMPUTE_DXDY;
                end
            end
            COMPUTE_DXDY: begin
                dx <= $signed(b_i_reg) * $signed(c_j_reg) - $signed(b_j_reg) * $signed(c_i_reg);
                dy <= $signed(c_i_reg) * $signed(a_j_reg) - $signed(c_j_reg) * $signed(a_i_reg);
                state <= SQUARE;
            end
            SQUARE: begin
                lhs <= dx * dx + dy * dy;
                rhs <= ($signed(r) * $signed(r)) * (det * det);
                state <= COMPARE;
            end
            COMPARE: begin
                if (lhs < rhs) begin
                    I <= I + 16'd1;
                end
                state <= NEXT_PAIR;
            end
            NEXT_PAIR: begin
                if (j < m - 8'd1) begin
                    j <= j + 8'd1;
                    state <= INIT_PAIR;
                end else begin
                    j <= i + 8'd2;
                    if (i < m - 8'd2) begin
                        i <= i + 8'd1;
                        state <= INIT_PAIR;
                    end else begin
                        state <= CHECK_F;
                    end
                end
            end
            CHECK_F: begin
                F <= 16'd1 + {8'd0, m} + I;
                state <= COMPARE_F;
            end
            COMPARE_F: begin
                if (F != {8'd0, n}) begin
                    result <= 1'b0;
                    state <= DONE;
                end else begin
                    k <= 8'd0;
                    state <= INIT_SIG;
                end
            end
            INIT_SIG: begin
                current_sig <= {M{1'b0}};
                l <= 8'd0;
                state <= COMPUTE_SIG;
            end
            COMPUTE_SIG: begin
                if (val_current > 64'sd0) begin
                    current_sig[l] <= 1'b1;
                end else begin
                    current_sig[l] <= 1'b0;
                end
                if (l < m - 8'd1) begin
                    l <= l + 8'd1;
                    state <= COMPUTE_SIG;
                end else begin
                    state <= NEXT_CANDLE;
                end
            end
            NEXT_CANDLE: begin
                signatures[k] <= current_sig;
                k <= k + 8'd1;
                if (k < n - 8'd1) begin
                    state <= INIT_SIG;
                end else begin
                    state <= CHECK_DUP;
                end
            end
            CHECK_DUP: begin
                duplicate_found <= duplicate_found_wire;
                state <= DONE;
            end
            DONE: begin
                done <= 1'b1;
                if (duplicate_found) begin
                    result <= 1'b0;
                end else begin
                    result <= 1'b1;
                end
                state <= IDLE;
            end
            default: state <= IDLE;
        endcase
    end
end

endmodule