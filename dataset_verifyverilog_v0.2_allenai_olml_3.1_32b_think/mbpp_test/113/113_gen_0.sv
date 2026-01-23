module check_integer (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [2:0] char_idx,
    input valid_char,
    output reg result,
    output reg done,
    output reg error
);

localparam IDLE = 3'd0;
localparam CHECK_FIRST = 3'd1;
localparam CHECK_REMAINING = 3'd2;
localparam VALID = 3'd3;
localparam INVALID = 3'd4;
localparam DONE_STATE = 3'd5;

reg [2:0] state;
reg [7:0] stored_chars [7:0];
reg [2:0] expected_idx;
reg valid_first;
reg all_digits;
reg non_null_count;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        expected_idx <= 0;
        non_null_count <=0;
        valid_first <=0;
        all_digits <=1;
        result <=0;
        done <=0;
        error <=0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                state <= CHECK_FIRST;
                expected_idx <=0;
                non_null_count <=0;
                valid_first <=0;
                all_digits <=1;
            end
        end else if (state == CHECK_FIRST) begin
            if (char_idx == expected_idx) begin
                stored_chars[expected_idx] <= char_in;
                if (char_in !=0) begin
                    non_null_count <= non_null_count +1;
                    if (char_in == 0x2B || char_in == 0x2D || (char_in >=0x30 && char_in <=0x39)) begin
                        valid_first <=1;
                    end else begin
                        valid_first <=0;
                        all_digits <=0;
                    end
                end
                expected_idx <= expected_idx +1;
                if (expected_idx ==1) begin
                    state <= CHECK_REMAINING;
                end
            end else begin
                all_digits <=0;
                state <= INVALID;
            end
        end else if (state == CHECK_REMAINING) begin
            if (char_idx == expected_idx) begin
                stored_chars[expected_idx] <= char_in;
                if (char_in !=0) begin
                    if (char_in <0x30 || char_in >0x39) begin
                        all_digits <=0;
                    end
                    non_null_count <= non_null_count +1;
                end
                expected_idx <= expected_idx +1;
                if (expected_idx ==8) begin
                    state <= DONE_STATE;
                end
            end else begin
                all_digits <=0;
                state <= INVALID;
            end
        end else if (state == DONE_STATE) begin
            if (non_null_count ==0) begin
                error <=1;
                result <=0;
            end else begin
                error <=0;
                if (valid_first && all_digits) begin
                    result <=1;
                end else begin
                    result <=0;
                end
            end
            done <=1;
        end else if (state == INVALID) begin
            result <=0;
            error <=0;
            done <=1;
        end
    end
end

assign result = check_integer.result;
assign done = check_integer.done;
assign error = check_integer.error;
