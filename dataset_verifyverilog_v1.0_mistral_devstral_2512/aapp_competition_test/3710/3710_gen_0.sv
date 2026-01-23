module remainder_game (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [15:0] k,
    input [15:0] c_0, c_1, c_2, c_3, c_4, c_5, c_6, c_7,
    output reg done,
    output reg result
);

// Parameters
parameter N_MAX = 8;
parameter DATA_WIDTH = 16;

// Internal registers
reg [DATA_WIDTH-1:0] L;
reg [3:0] i;
reg [3:0] state;
reg [DATA_WIDTH-1:0] temp_g;
reg [DATA_WIDTH-1:0] temp_h;
reg [DATA_WIDTH-1:0] temp_div;
reg [DATA_WIDTH-1:0] c_reg;
reg gcd_start, div_start;
reg [DATA_WIDTH-1:0] gcd_a, gcd_b;
reg [DATA_WIDTH-1:0] div_dividend, div_divisor;
wire [DATA_WIDTH-1:0] gcd_out;
wire gcd_done;
wire [DATA_WIDTH-1:0] div_quotient;
wire div_done;

// States
localparam [1:0] IDLE = 2'd0;
localparam [1:0] CHECK_INDEX = 2'd1;
localparam [1:0] GET_C = 2'd2;
localparam [1:0] COMPUTE_GCD_K_C = 2'd3;
localparam [1:0] COMPUTE_GCD_L_G = 2'd4;
localparam [1:0] COMPUTE_DIV = 2'd5;
localparam [1:0] COMPUTE_MUL = 2'd6;
localparam [1:0] UPDATE_L = 2'd7;
localparam [1:0] COMPARE_RESULT = 2'd8;
localparam [1:0] DONE_STATE = 2'd9;

// GCD module instance
gcd_module #(.DATA_WIDTH(DATA_WIDTH)) gcd_inst (
    .clk(clk),
    .rst_n(rst_n),
    .start(gcd_start),
    .a(gcd_a),
    .b(gcd_b),
    .gcd(gcd_out),
    .done(gcd_done)
);

// Division module instance
div_module #(.DATA_WIDTH(DATA_WIDTH)) div_inst (
    .clk(clk),
    .rst_n(rst_n),
    .start(div_start),
    .dividend(div_dividend),
    .divisor(div_divisor),
    .quotient(div_quotient),
    .done(div_done)
);

// Main FSM
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 1'b0;
        L <= 16'd1;
        i <= 4'd0;
        gcd_start <= 1'b0;
        div_start <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    L <= 16'd1;
                    i <= 4'd0;
                    state <= CHECK_INDEX;
                end
            end

            CHECK_INDEX: begin
                if (i < n) begin
                    state <= GET_C;
                end else begin
                    state <= COMPARE_RESULT;
                end
            end

            GET_C: begin
                case (i)
                    4'd0: c_reg <= c_0;
                    4'd1: c_reg <= c_1;
                    4'd2: c_reg <= c_2;
                    4'd3: c_reg <= c_3;
                    4'd4: c_reg <= c_4;
                    4'd5: c_reg <= c_5;
                    4'd6: c_reg <= c_6;
                    4'd7: c_reg <= c_7;
                    default: c_reg <= c_0;
                endcase
                state <= COMPUTE_GCD_K_C;
            end

            COMPUTE_GCD_K_C: begin
                if (!gcd_start) begin
                    gcd_a <= k;
                    gcd_b <= c_reg;
                    gcd_start <= 1'b1;
                end else if (gcd_done) begin
                    gcd_start <= 1'b0;
                    temp_g <= gcd_out;
                    state <= COMPUTE_GCD_L_G;
                end
            end

            COMPUTE_GCD_L_G: begin
                if (!gcd_start) begin
                    gcd_a <= L;
                    gcd_b <= temp_g;
                    gcd_start <= 1'b1;
                end else if (gcd_done) begin
                    gcd_start <= 1'b0;
                    temp_h <= gcd_out;
                    state <= COMPUTE_DIV;
                end
            end

            COMPUTE_DIV: begin
                if (!div_start) begin
                    div_dividend <= L;
                    div_divisor <= temp_h;
                    div_start <= 1'b1;
                end else if (div_done) begin
                    div_start <= 1'b0;
                    temp_div <= div_quotient;
                    state <= COMPUTE_MUL;
                end
            end

            COMPUTE_MUL: begin
                L <= temp_div * temp_g;
                state <= UPDATE_L;
            end

            UPDATE_L: begin
                i <= i + 4'd1;
                state <= CHECK_INDEX;
            end

            COMPARE_RESULT: begin
                if (L == k) begin
                    result <= 1'b1;
                end else begin
                    result <= 1'b0;
                end
                done <= 1'b1;
                state <= DONE_STATE;
            end

            DONE_STATE: begin
                done <= 1'b0;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule

// GCD Module
module gcd_module #(
    parameter DATA_WIDTH = 16
)(
    input clk,
    input rst_n,
    input start,
    input [DATA_WIDTH-1:0] a,
    input [DATA_WIDTH-1:0] b,
    output reg [DATA_WIDTH-1:0] gcd,
    output reg done
);

reg [DATA_WIDTH-1:0] u, v;
reg [DATA_WIDTH-1:0] shift;
reg [1:0] state;

localparam [1:0] IDLE = 2'd0;
localparam [1:0] COMPUTE = 2'd1;
localparam [1:0] DONE = 2'd2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        gcd <= 16'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    u <= a;
                    v <= b;
                    shift <= 16'd0;
                    state <= COMPUTE;
                end
            end

            COMPUTE: begin
                if (u == 16'd0) begin
                    gcd <= v << shift;
                    state <= DONE;
                end else if (v == 16'd0) begin
                    gcd <= u << shift;
                    state <= DONE;
                end else if (u[0] == 1'b0 && v[0] == 1'b0) begin
                    u <= u >> 1;
                    v <= v >> 1;
                    shift <= shift + 16'd1;
                end else if (u[0] == 1'b0) begin
                    u <= u >> 1;
                end else if (v[0] == 1'b0) begin
                    v <= v >> 1;
                end else if (u > v) begin
                    u <= u - v;
                end else begin
                    v <= v - u;
                end
            end

            DONE: begin
                done <= 1'b1;
                state <= IDLE;
            end
        endcase
    end
end

endmodule

// Division Module (unsigned, exact division)
module div_module #(
    parameter DATA_WIDTH = 16
)(
    input clk,
    input rst_n,
    input start,
    input [DATA_WIDTH-1:0] dividend,
    input [DATA_WIDTH-1:0] divisor,
    output reg [DATA_WIDTH-1:0] quotient,
    output reg done
);

reg [DATA_WIDTH-1:0] rem;
reg [DATA_WIDTH-1:0] div;
reg [DATA_WIDTH-1:0] quot;
reg [5:0] count;
reg [1:0] state;

localparam [1:0] IDLE = 2'd0;
localparam [1:0] COMPUTE = 2'd1;
localparam [1:0] DONE = 2'd2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        quotient <= 16'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    rem <= dividend;
                    div <= divisor;
                    quot <= 16'd0;
                    count <= 6'd16;
                    state <= COMPUTE;
                end
            end

            COMPUTE: begin
                if (count == 6'd0) begin
                    quotient <= quot;
                    state <= DONE;
                end else begin
                    rem <= {rem[14:0], 1'b0};
                    quot <= {quot[14:0], 1'b0};
                    if (rem >= div) begin
                        quot[0] <= 1'b1;
                        rem <= rem - div;
                    end
                    count <= count - 6'd1;
                end
            end

            DONE: begin
                done <= 1'b1;
                state <= IDLE;
            end
        endcase
    end
end

endmodule