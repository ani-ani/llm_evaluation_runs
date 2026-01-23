module extract_quotation(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] input_len,
    input wire [7:0] input_str [0:63],
    output reg [5:0] count,
    output reg [4:0] found_len0,
    output reg [4:0] found_len1,
    output reg [4:0] found_len2,
    output reg [4:0] found_len3,
    output reg [7:0] found0 [0:15],
    output reg [7:0] found1 [0:15],
    output reg [7:0] found2 [0:15],
    output reg [7:0] found3 [0:15],
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SCANNING = 2'd1;
    localparam [1:0] FINISHED = 2'd2;

    reg [1:0] state;
    reg [1:0] next_state;
    reg [5:0] scan_idx;
    reg [2:0] sub_idx;
    reg [3:0] char_idx;
    reg in_quotes;
    reg [7:0] quote_char;
    reg [5:0] count_reg;
    reg [4:0] found_len_reg [0:3];
    reg [7:0] found_reg0 [0:15];
    reg [7:0] found_reg1 [0:15];
    reg [7:0] found_reg2 [0:15];
    reg [7:0] found_reg3 [0:15];
    reg done_reg;
    reg found_quote;
    integer i;

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start && input_len > 0) next_state = SCANNING;
            end
            SCANNING: begin
                if (scan_idx >= input_len || sub_idx >= 4) next_state = FINISHED;
            end
            FINISHED: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            scan_idx <= 6'd0;
            sub_idx <= 3'd0;
            char_idx <= 4'd0;
            in_quotes <= 1'b0;
            quote_char <= 8'd0;
            count_reg <= 6'd0;
            done_reg <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                found_reg0[i] <= 8'd0;
                found_reg1[i] <= 8'd0;
                found_reg2[i] <= 8'd0;
                found_reg3[i] <= 8'd0;
            end
            for (i = 0; i < 4; i = i + 1) begin
                found_len_reg[i] <= 5'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done_reg <= 1'b0;
                    if (start && input_len > 0) begin
                        scan_idx <= 6'd0;
                        sub_idx <= 3'd0;
                        char_idx <= 4'd0;
                        in_quotes <= 1'b0;
                        quote_char <= 8'd0;
                        count_reg <= 6'd0;
                    end
                end
                SCANNING: begin
                    if (scan_idx < input_len && sub_idx < 4) begin
                        found_quote = (input_str[scan_idx] == 8'h22) || (input_str[scan_idx] == 8'h27);
                        if (!in_quotes) begin
                            if (found_quote) begin
                                in_quotes <= 1'b1;
                                quote_char <= input_str[scan_idx];
                                char_idx <= 4'd0;
                            end
                        end else begin
                            if (found_quote && (input_str[scan_idx] == quote_char)) begin
                                in_quotes <= 1'b0;
                                case (sub_idx)
                                    3'd0: found_len_reg[0] <= char_idx;
                                    3'd1: found_len_reg[1] <= char_idx;
                                    3'd2: found_len_reg[2] <= char_idx;
                                    3'd3: found_len_reg[3] <= char_idx;
                                endcase
                                sub_idx <= sub_idx + 3'd1;
                                count_reg <= {3'd0, sub_idx} + 6'd1;
                            end else if (char_idx < 16) begin
                                case (sub_idx)
                                    3'd0: found_reg0[char_idx] <= input_str[scan_idx];
                                    3'd1: found_reg1[char_idx] <= input_str[scan_idx];
                                    3'd2: found_reg2[char_idx] <= input_str[scan_idx];
                                    3'd3: found_reg3[char_idx] <= input_str[scan_idx];
                                endcase
                                char_idx <= char_idx + 4'd1;
                            end
                        end
                        scan_idx <= scan_idx + 6'd1;
                    end
                end
                FINISHED: begin
                    done_reg <= 1'b1;
                end
            endcase
        end
    end

    always @(*) begin
        count = count_reg;
        found_len0 = found_len_reg[0];
        found_len1 = found_len_reg[1];
        found_len2 = found_len_reg[2];
        found_len3 = found_len_reg[3];
        found0 = found_reg0;
        found1 = found_reg1;
        found2 = found_reg2;
        found3 = found_reg3;
        done = done_reg;
    end

endmodule