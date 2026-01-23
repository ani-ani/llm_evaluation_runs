module fraction_simplifier (
    input clk,
    input rst_n,
    input start,
    input [127:0] frac1_str,
    input [127:0] frac2_str,
    output reg result,
    output reg done
);

localparam IDLE = 4'd0,
        PARSE_NUM1 = 4'd1,
        PARSE_DEN1 = 4'd2,
        PARSE_NUM2 = 4'd3,
        PARSE_DEN2 = 4'd4,
        MULTIPLY = 4'd5,
        GCD_LOOP = 4'd6,
        CHECK = 4'd7,
        DONE = 4'd8;

reg [63:0] num1, num2, den1, den2;
reg [63:0] num_prod_saved, den_prod_saved;
reg [63:0] num_prod, den_prod;
reg [7:0] frac1_pos, frac2_pos;
reg [3:0] state;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        frac1_pos <= 8'h0;
        frac2_pos <= 8'h0;
        num1 <= 32'h0;
        den1 <= 32'h0;
        num2 <= 32'h0;
        den2 <= 32'h0;
        num_prod_saved <= 64'h0;
        den_prod_saved <= 64'h0;
        num_prod <= 64'h0;
        den_prod <= 64'h0;
        result <= 1'b0;
        done <= 1'b0;
    end else begin
        state <= next_state;
        frac1_pos <= next_frac1_pos;
        frac2_pos <= next_frac2_pos;
        num1 <= next_num1;
        den1 <= next_den1;
        num2 <= next_num2;
        den2 <= next_den2;
        num_prod_saved <= next_num_prod_saved;
        den_prod_saved <= next_den_prod_saved;
        num_prod <= next_num_prod;
        den_prod <= next_den_prod;
        result <= next_result;
        done <= next_done;
    end
end

always @(*) begin
    // Default assignments
    next_state = state;
    next_frac1_pos = frac1_pos;
    next_frac2_pos = frac2_pos;
    next_num1 = num1;
    next_den1 = den1;
    next_num2 = num2;
    next_den2 = den2;
    next_num_prod_saved = num_prod_saved;
    next_den_prod_saved = den_prod_saved;
    next_num_prod = num_prod;
    next_den_prod = den_prod;
    next_result = result;
    next_done = done;

    case (state)
        IDLE: begin
            if (start) begin
                next_state = PARSE_NUM1;
                next_frac1_pos <= 8'h0;
                next_frac2_pos <= 8'h0;
                next_num1 <= 32'h0;
                next_den1 <= 32'h0;
                next_num2 <= 32'h0;
                next_den2 <= 32'h0;
            end
        end

        PARSE_NUM1: begin
            wire [7:0] c = frac1_str[frac1_pos];
            if (c >= 8'h30 && c <= 8'h39) begin
                next_num1 = num1 * 10 + (c - 8'h30);
                next_frac1_pos = frac1_pos + 1;
            end else if (c == 8'h2F) begin
                next_state = PARSE_DEN1;
                next_frac1_pos = frac1_pos + 1;
            end else begin
                next_frac1_pos = frac1_pos + 1;
            end
        end

        PARSE_DEN1: begin
            if (frac1_pos >= 16) begin
                next_state = PARSE_NUM2;
                next_frac2_pos <= 8'h0;
            end else begin
                wire [7:0] c = frac1_str[frac1_pos];
                if (c >= 8'h30 && c <= 8'h39) begin
                    next_den1 = den1 * 10 + (c - 8'h30);
                    next_frac1_pos = frac1_pos + 1;
                end else begin
                    next_frac1_pos = frac1_pos + 1;
                end
            end
        end

        PARSE_NUM2: begin
            wire [7:0] c = frac2_str[frac2_pos];
            if (c >= 8'h30 && c <= 8'h39) begin
                next_num2 = num2 * 10 + (c - 8'h30);
                next_frac2_pos = frac2_pos + 1;
            end else if (c == 8'h2F) begin
                next_state = PARSE_DEN2;
                next_frac2_pos = frac2_pos + 1;
            end else begin
                next_frac2_pos = frac2_pos + 1;
            end
        end

        PARSE_DEN2: begin
            if (frac2_pos >= 16) begin
                next_state = MULTIPLY;
            end else begin
                wire [7:0] c = frac2_str[frac2_pos];
                if (c >= 8'h30 && c <= 8'h39) begin
                    next_den2 = den2 * 10 + (c - 8'h30);
                    next_frac2_pos = frac2_pos + 1;
                end else begin
                    next_frac2_pos = frac2_pos + 1;
                end
            end
        end

        MULTIPLY: begin
            next_num_prod_saved = num1 * num2;
            next_den_prod_saved = den1 * den2;
            next_num_prod = next_num_prod_saved;
            next_den_prod = next_den_prod_saved;
            next_state = GCD_LOOP;
        end

        GCD_LOOP: begin
            if (den_prod == 0) begin
                next_state = CHECK;
            end else begin
                reg [63:0] new_num_prod, new_den_prod;
                new_num_prod = den_prod;
                new_den_prod = num_prod % den_prod;
                next_num_prod = new_num_prod;
                next_den_prod = new_den_prod;
                next_state = GCD_LOOP;
            end
        end

        CHECK: begin
            if (num_prod == den_prod_saved) begin
                next_result = 1'b1;
            end else begin
                next_result = 1'b0;
            end
            next_state = DONE;
            next_done = 1'b1;
        end

        DONE: begin
            next_done = 1'b1;
        end

        default: next_state = state;
    endcase
end

assign result = next_result;
assign done = next_done;

endmodule