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
localparam [3:0] IDLE = 4'd0;
localparam [3:0] INIT_PAIR = 4'd1;
localparam [3:0] COMPUTE_DET = 4'd2;
localparam [3:0] CHECK_DET = 4'd3;
localparam [3:0] COMPUTE_DXDY = 4'd4;
localparam [3:0] SQUARE = 4'd5;
localparam [3:0] COMPARE = 4'd6;
localparam [3:0] NEXT_PAIR = 4'd7;
localparam [3:0] CHECK_F = 4'd8;
localparam [3:0] COMPARE_F = 4'd9;
localparam [3:0] INIT_SIG = 4'd10;
localparam [3:0] COMPUTE_SIG = 4'd11;
localparam [3:0] NEXT_CANDLE = 4'd12;
localparam [3:0] CHECK_DUP = 4'd13;
localparam [3:0] DONE = 4'd14;

reg [3:0] state;
reg [3:0] i, j;
reg [3:0] k;
reg [3:0] l;
reg signed [63:0] det;
reg signed [63:0] dx, dy;
reg signed [63:0] lhs, rhs;
reg [3:0] I;
reg [7:0] F;
reg [M-1:0] signatures [0:N-1];
reg [M-1:0] current_sig;
reg duplicate_found;

reg signed [31:0] a_i;
reg signed [31:0] b_i;
reg signed [31:0] c_i;
reg signed [31:0] a_j;
reg signed [31:0] b_j;
reg signed [31:0] c_j;

wire signed [63:0] val_current;
assign val_current = $signed(a_lines[l]) * $signed(x_candles[k]) + $signed(b_lines[l]) * $signed(y_candles[k]) + $signed(c_lines[l]);

integer idx, idx_i, idx_j;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 1'b0;
        I <= 4'd0;
        F <= 8'd0;
        i <= 4'd0;
        j <= 4'd0;
        k <= 4'd0;
        l <= 4'd0;
        det <= 64'd0;
        dx <= 64'd0;
        dy <= 64'd0;
        lhs <= 64'd0;
        rhs <= 64'd0;
        duplicate_found <= 1'b0;
        a_i <= 32'd0;
        b_i <= 32'd0;
        c_i <= 32'd0;
        a_j <= 32'd0;
        b_j <= 32'd0;
        c_j <= 32'd0;
        current_sig <= {M{1'b0}};
        for (idx = 0; idx < N; idx = idx + 1) begin
            signatures[idx] <= {M{1'b0}};
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= INIT_PAIR;
                    I <= 4'd0;
                    i <= 4'd0;
                    j <= 4'd1;
                end
            end
            
            INIT_PAIR: begin
                a_i <= a_lines[i];
                b_i <= b_lines[i];
                c_i <= c_lines[i];
                a_j <= a_lines[j];
                b_j <= b_lines[j];
                c_j <= c_lines[j];
                state <= COMPUTE_DET;
            end
            
            COMPUTE_DET: begin
                det <= $signed(a_i) * $signed(b_j) - $signed(a_j) * $signed(b_i);
                state <= CHECK_DET;
            end
            
            CHECK_DET: begin
                if (det == 64'd0) begin
                    state <= NEXT_PAIR;
                end else begin
                    state <= COMPUTE_DXDY;
                end
            end
            
            COMPUTE_DXDY: begin
                dx <= $signed(b_i) * $signed(c_j) - $signed(b_j) * $signed(c_i);
                dy <= $signed(c_i) * $signed(a_j) - $signed(c_j) * $signed(a_i);
                state <= SQUARE;
            end
            
            SQUARE: begin
                lhs <= $signed(dx) * $signed(dx) + $signed(dy) * $signed(dy);
                rhs <= ($signed(r) * $signed(r)) * ($signed(det) * $signed(det));
                state <= COMPARE;
            end
            
            COMPARE: begin
                if ($signed(lhs) < $signed(rhs)) begin
                    I <= I + 4'd1;
                end
                state <= NEXT_PAIR;
            end
            
            NEXT_PAIR: begin
                if (j < m - 8'd1) begin
                    j <= j + 4'd1;
                    state <= INIT_PAIR;
                end else begin
                    j <= i + 4'd2;
                    if (i < m - 8'd2) begin
                        i <= i + 4'd1;
                        state <= INIT_PAIR;
                    end else begin
                        state <= CHECK_F;
                    end
                end
            end
            
            CHECK_F: begin
                F <= 8'd1 + m + I;
                state <= COMPARE_F;
            end
            
            COMPARE_F: begin
                if (F != n) begin
                    result <= 1'b0;
                    state <= DONE;
                end else begin
                    k <= 4'd0;
                    state <= INIT_SIG;
                end
            end
            
            INIT_SIG: begin
                current_sig <= {M{1'b0}};
                l <= 4'd0;
                state <= COMPUTE_SIG;
            end
            
            COMPUTE_SIG: begin
                if ($signed(val_current) > 64'd0) begin
                    current_sig[l] <= 1'b1;
                end else begin
                    current_sig[l] <= 1'b0;
                end
                if (l < m - 4'd1) begin
                    l <= l + 4'd1;
                    state <= COMPUTE_SIG;
                end else begin
                    state <= NEXT_CANDLE;
                end
            end
            
            NEXT_CANDLE: begin
                signatures[k] <= current_sig;
                k <= k + 4'd1;
                if (k < n - 8'd1) begin
                    state <= INIT_SIG;
                end else begin
                    state <= CHECK_DUP;
                    duplicate_found <= 1'b0;
                end
            end
            
            CHECK_DUP: begin
                duplicate_found <= 1'b0;
                for (idx_i = 0; idx_i < N; idx_i = idx_i + 1) begin
                    for (idx_j = idx_i + 1; idx_j < N; idx_j = idx_j + 1) begin
                        if (idx_i < n && idx_j < n && signatures[idx_i] == signatures[idx_j]) begin
                            duplicate_found <= 1'b1;
                        end
                    end
                end
                state <= DONE;
            end
            
            DONE: begin
                done <= 1'b1;
                result <= !duplicate_found;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule