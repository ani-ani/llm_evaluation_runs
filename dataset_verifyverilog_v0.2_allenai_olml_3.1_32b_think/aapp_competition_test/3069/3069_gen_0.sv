module bracket_validator (
    input clk,
    input rst_n,
    input start,
    input [15:0][7:0] bracket_str,
    input [4:0] str_len,
    output reg result,
    output reg done
);
reg [2:0] state;
reg [4:0] l, r, original_pos, check_pos, str_len_reg;
reg signed [4:0] balance, segment_balance;
reg is_original_valid;
reg any_negative;
reg segment_any_negative;
reg segment_valid;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 0;
        l <=0; r <=0; original_pos <=0; check_pos <=0; str_len_reg <=0;
        balance <=0; segment_balance <=0;
        is_original_valid <=0;
        any_negative <=0; segment_any_negative <=0; segment_valid <=0;
        result <=0; done <=0;
    end else begin
        if (start) begin
            if (state == 0) begin
                str_len_reg <= str_len;
                state <= 1;
                original_pos <=0;
                balance <=0;
                any_negative <=0;
            end
        end
        if (state == 1) begin
            if (str_len_reg ==0) begin
                is_original_valid <=1;
                state <=5;
                result <=1;
                done <=1;
            end else if (original_pos < str_len_reg) begin
                if (bracket_str[original_pos][7:0] == 8'h28) begin
                    balance = balance +1;
                end else if (bracket_str[original_pos][7:0] == 8'h29) begin
                    balance = balance -1;
                end
                if (balance <0) any_negative <=1;
                original_pos <= original_pos +1;
            end else begin
                is_original_valid <= (balance ==0) && !any_negative;
                if (is_original_valid) begin
                    state <=5;
                    result <=1;
                    done <=1;
                end else begin
                    l <=0; r <=0;
                    state <=2;
                end
            end
        end else if (state ==2) begin
            check_pos <=0;
            segment_balance <=0;
            segment_any_negative <=0;
            segment_valid <=0;
            state <=3;
        end else if (state ==3) begin
            if (check_pos < str_len_reg) begin
                if (check_pos >= l && check_pos <= r) begin
                    if (bracket_str[check_pos][7:0] == 8'h28) begin
                        segment_balance = segment_balance +1;
                    end else if (bracket_str[check_pos][7:0] == 8'h29) begin
                        segment_balance = segment_balance -1;
                    end
                end else begin
                    if (bracket_str[check_pos][7:0] == 8'h28) begin
                        segment_balance = segment_balance +1;
                    end else if (bracket_str[check_pos][7:0] == 8'h29) begin
                        segment_balance = segment_balance -1;
                    end
                end
                if (segment_balance <0) segment_any_negative <=1;
                check_pos <= check_pos +1;
            end else begin
                segment_valid <= (segment_balance ==0) && !segment_any_negative;
                state <=4;
            end
        end else if (state ==4) begin
            if (segment_valid) begin
                result <=1;
                done <=1;
                state <=5;
            end else begin
                if (r < str_len_reg -1) begin
                    r <= r +1;
                end else begin
                    l <= l +1;
                    if (l < str_len_reg) begin
                        r <= l;
                    end else begin
                        result <=0;
                        done <=1;
                        state <=5;
                    end
                end
                check_pos <=0;
                segment_balance <=0;
                segment_any_negative <=0;
                segment_valid <=0;
                state <=3;
            end
        end
    end
endmodule