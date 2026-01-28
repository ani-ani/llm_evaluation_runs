module rational_to_fraction (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [9:0] integer_part,
    input wire [43:0] digits_packed,
    input wire [3:0] L,
    input wire [3:0] R,
    output reg [63:0] numerator,
    output reg [63:0] denominator,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_A = 3'd1;
    localparam [2:0] COMPUTE_B = 3'd2;
    localparam [2:0] COMPUTE_DENOM = 3'd3;
    localparam [2:0] COMPUTE_NUM = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;
    reg [9:0] int_part_reg;
    reg [43:0] digits_packed_reg;
    reg [3:0] L_reg;
    reg [3:0] R_reg;
    reg [3:0] K;
    reg [3:0] i;
    reg [3:0] j;
    reg [63:0] A;
    reg [63:0] B;
    reg [63:0] pow10_K;
    reg [63:0] pow10_R;
    reg [63:0] denom;
    reg [63:0] num;

    function [63:0] pow10;
        input [3:0] n;
        begin
            case(n)
                4'd0: pow10 = 64'd1;
                4'd1: pow10 = 64'd10;
                4'd2: pow10 = 64'd100;
                4'd3: pow10 = 64'd1000;
                4'd4: pow10 = 64'd10000;
                4'd5: pow10 = 64'd100000;
                4'd6: pow10 = 64'd1000000;
                4'd7: pow10 = 64'd10000000;
                4'd8: pow10 = 64'd100000000;
                4'd9: pow10 = 64'd1000000000;
                4'd10: pow10 = 64'd10000000000;
                4'd11: pow10 = 64'd100000000000;
                default: pow10 = 64'd0;
            endcase
        end
    endfunction

    wire [3:0] digit [0:10];
    integer g;
    always @(*) begin
        for (g = 0; g <= 10; g = g + 1) begin
            digit[g] = (digits_packed_reg >> (4*(10-g))) & 4'hF;
        end
    end

    always @(*) begin
        next_state = state;
        case(state)
            IDLE: begin
                if (start) begin
                    if (L_reg - R_reg == 0)
                        next_state = COMPUTE_B;
                    else
                        next_state = COMPUTE_A;
                end
            end
            COMPUTE_A: begin
                if (i < K)
                    next_state = COMPUTE_A;
                else
                    next_state = COMPUTE_B;
            end
            COMPUTE_B: begin
                if (j < R_reg)
                    next_state = COMPUTE_B;
                else
                    next_state = COMPUTE_DENOM;
            end
            COMPUTE_DENOM: begin
                next_state = COMPUTE_NUM;
            end
            COMPUTE_NUM: begin
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            int_part_reg <= 10'd0;
            digits_packed_reg <= 44'd0;
            L_reg <= 4'd0;
            R_reg <= 4'd0;
            K <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            A <= 64'd0;
            B <= 64'd0;
            pow10_K <= 64'd0;
            pow10_R <= 64'd0;
            denom <= 64'd0;
            num <= 64'd0;
            numerator <= 64'd0;
            denominator <= 64'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            done <= 1'b0;
            case(state)
                IDLE: begin
                    if (start) begin
                        int_part_reg <= integer_part;
                        digits_packed_reg <= digits_packed;
                        L_reg <= L;
                        R_reg <= R;
                        K <= L - R;
                        pow10_K <= pow10(L - R);
                        pow10_R <= pow10(R);
                        i <= 4'd0;
                        j <= 4'd0;
                        A <= 64'd0;
                        B <= 64'd0;
                    end
                end
                COMPUTE_A: begin
                    if (i < K) begin
                        A <= A * 10 + digit[i];
                        i <= i + 1;
                    end
                end
                COMPUTE_B: begin
                    if (j < R_reg) begin
                        B <= B * 10 + digit[K + j];
                        j <= j + 1;
                    end
                end
                COMPUTE_DENOM: begin
                    denom <= pow10_K * (pow10_R - 1);
                end
                COMPUTE_NUM: begin
                    num <= int_part_reg * denom + (A * pow10_R + B - A);
                end
                DONE_STATE: begin
                    numerator <= num;
                    denominator <= denom;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule