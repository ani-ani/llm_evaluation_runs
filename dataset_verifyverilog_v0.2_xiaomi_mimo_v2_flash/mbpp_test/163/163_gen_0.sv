module polygon_area (
    input clk,
    input rst_n,
    input start,
    input [15:0] s,
    input [31:0] l,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam CALC_LSQ = 3'b001;
    localparam CALC_TAN = 3'b010;
    localparam CALC_DIV = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state, next_state;
    reg [31:0] l_reg;
    reg [15:0] s_reg;
    reg [63:0] l_sq;
    reg [31:0] tan_val;
    reg [31:0] denominator;
    reg [63:0] div_rem;
    reg [31:0] div_quot;
    reg [5:0] div_count;
    reg [31:0] tan_table [1:12];

    // Initialize LUT
    always @(*) begin
        tan_table[3] = 32'h0001BB67;
        tan_table[4] = 32'h00010000;
        tan_table[5] = 32'h0000B9EF;
        tan_table[6] = 32'h000093D7;
        tan_table[7] = 32'h00007B63;
        tan_table[8] = 32'h00006A28;
        tan_table[9] = 32'h00005CC4;
        tan_table[10] = 32'h00005337;
        tan_table[11] = 32'h00004B5E;
        tan_table[12] = 32'h0000449D;
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? CALC_LSQ : IDLE;
            CALC_LSQ: next_state = CALC_TAN;
            CALC_TAN: next_state = CALC_DIV;
            CALC_DIV: begin
                if (div_count == 0) next_state = CALC_DIV;
                else if (div_count == 1) next_state = DONE;
                else next_state = CALC_DIV;
            end
            DONE: next_state = start ? DONE : IDLE;
            default: next_state = IDLE;
        endcase
    end

    // State Register and Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'b0;
            done <= 1'b0;
            l_reg <= 32'b0;
            s_reg <= 16'b0;
            l_sq <= 64'b0;
            tan_val <= 32'b0;
            denominator <= 32'b0;
            div_rem <= 64'b0;
            div_quot <= 32'b0;
            div_count <= 6'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        l_reg <= l;
                        s_reg <= s;
                    end
                end
                CALC_LSQ: begin
                    l_sq <= l_reg * l_reg;
                end
                CALC_TAN: begin
                    if (s_reg >= 3 && s_reg <= 12)
                        tan_val <= tan_table[s_reg];
                    else
                        tan_val <= 32'h00010000;
                end
                CALC_DIV: begin
                    if (div_count == 0) begin
                        denominator <= 4 * tan_val;
                        div_rem <= s_reg * l_sq;
                        div_quot <= 32'b0;
                        div_count <= 32;
                    end else begin
                        if ((div_rem << 1)[63:32] >= denominator) begin
                            div_rem <= { (div_rem << 1)[63:32] - denominator, (div_rem << 1)[31:0] };
                            div_quot <= (div_quot << 1) | 1'b1;
                        end else begin
                            div_rem <= div_rem << 1;
                            div_quot <= (div_quot << 1) | 1'b0;
                        end
                        div_count <= div_count - 1;
                    end
                end
                DONE: begin
                    result <= div_quot;
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule