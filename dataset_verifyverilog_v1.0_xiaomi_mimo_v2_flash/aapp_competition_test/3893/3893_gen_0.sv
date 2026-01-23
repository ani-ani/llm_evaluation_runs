module crazy_town_solver (
    input clk, rst_n, start,
    input [8:0] wr_addr,
    input [62:0] wr_data,
    input wr_en,
    input [20:0] x1, y1,
    input [20:0] x2, y2,
    input [8:0] n,
    output reg [8:0] count,
    output reg done
);

    reg [62:0] mem [0:299];

    localparam [3:0] S_IDLE = 4'd0;
    localparam [3:0] S_READ = 4'd1;
    localparam [3:0] S_MULT1 = 4'd2;
    localparam [3:0] S_MULT2 = 4'd3;
    localparam [3:0] S_ADD1 = 4'd4;
    localparam [3:0] S_ADD2 = 4'd5;
    localparam [3:0] S_ADD3 = 4'd6;
    localparam [3:0] S_ADD4 = 4'd7;
    localparam [3:0] S_CHECK = 4'd8;
    localparam [3:0] S_NEXT = 4'd9;
    localparam [3:0] S_DONE = 4'd10;

    reg [3:0] state;
    reg [8:0] line_index;
    reg [8:0] count_reg;
    reg [20:0] a_reg, b_reg, c_reg;
    reg [41:0] ax1, ax2, by1, by2;
    reg [41:0] sum1, sum2;
    reg [41:0] value1, value2;
    reg [20:0] mult1_a, mult1_b, mult2_a, mult2_b;
    wire [41:0] mult1_out, mult2_out;
    reg [41:0] adder1_a, adder1_b, adder2_a, adder2_b;
    wire [41:0] adder1_out, adder2_out;

    assign mult1_out = $signed(mult1_a) * $signed(mult1_b);
    assign mult2_out = $signed(mult2_a) * $signed(mult2_b);
    assign adder1_out = $signed(adder1_a) + $signed(adder1_b);
    assign adder2_out = $signed(adder2_a) + $signed(adder2_b);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            line_index <= 9'd0;
            count_reg <= 9'd0;
            done <= 1'b0;
            a_reg <= 21'd0; b_reg <= 21'd0; c_reg <= 21'd0;
            ax1 <= 42'd0; ax2 <= 42'd0; by1 <= 42'd0; by2 <= 42'd0;
            sum1 <= 42'd0; sum2 <= 42'd0;
            value1 <= 42'd0; value2 <= 42'd0;
            mult1_a <= 21'd0; mult1_b <= 21'd0;
            mult2_a <= 21'd0; mult2_b <= 21'd0;
            adder1_a <= 42'd0; adder1_b <= 42'd0;
            adder2_a <= 42'd0; adder2_b <= 42'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        line_index <= 9'd0;
                        count_reg <= 9'd0;
                        state <= S_READ;
                    end
                end
                S_READ: begin
                    {a_reg, b_reg, c_reg} <= mem[line_index];
                    state <= S_MULT1;
                end
                S_MULT1: begin
                    mult1_a <= a_reg; mult1_b <= x1;
                    mult2_a <= a_reg; mult2_b <= x2;
                    state <= S_MULT2;
                end
                S_MULT2: begin
                    ax1 <= mult1_out;
                    ax2 <= mult2_out;
                    mult1_a <= b_reg; mult1_b <= y1;
                    mult2_a <= b_reg; mult2_b <= y2;
                    state <= S_ADD1;
                end
                S_ADD1: begin
                    by1 <= mult1_out;
                    by2 <= mult2_out;
                    state <= S_ADD2;
                end
                S_ADD2: begin
                    adder1_a <= ax1; adder1_b <= by1;
                    adder2_a <= ax2; adder2_b <= by2;
                    state <= S_ADD3;
                end
                S_ADD3: begin
                    sum1 <= adder1_out;
                    sum2 <= adder2_out;
                    state <= S_ADD4;
                end
                S_ADD4: begin
                    adder1_a <= sum1;
                    adder1_b <= {{21{c_reg[20]}}, c_reg};
                    adder2_a <= sum2;
                    adder2_b <= {{21{c_reg[20]}}, c_reg};
                    state <= S_CHECK;
                end
                S_CHECK: begin
                    value1 <= adder1_out;
                    value2 <= adder2_out;
                    if (adder1_out[41] != adder2_out[41])
                        count_reg <= count_reg + 9'd1;
                    state <= S_NEXT;
                end
                S_NEXT: begin
                    line_index <= line_index + 9'd1;
                    if (line_index == n - 9'd1)
                        state <= S_DONE;
                    else
                        state <= S_READ;
                end
                S_DONE: begin
                    done <= 1'b1;
                    if (!start)
                        state <= S_IDLE;
                end
                default: state <= S_IDLE;
            endcase
        end
    end

    always @(posedge clk) begin
        if (wr_en) begin
            mem[wr_addr] <= wr_data;
        end
    end

    always @(*) begin
        count = count_reg;
    end

endmodule