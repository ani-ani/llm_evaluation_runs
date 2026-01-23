module check_string_char (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [7:0] char_in,
    input valid_in,
    input last_in,
    output reg result,
    output reg done
);
reg [7:0] start_char;
reg [7:0] last_char;
reg [2:0] counter;
reg processing;
reg char_received;

always @(posedge clk) begin
    if (!rst_n) begin
        start_char <= 0;
        last_char <= 0;
        counter <= 0;
        processing <= 0;
        char_received <= 0;
        result <= 0;
        done <= 0;
    end else if (!processing) begin
        if (start == 1) begin
            processing <= 1;
            counter <= 0;
            start_char <= 0;
            last_char <= 0;
            char_received <= 0;
        end
    end else begin
        if (counter < 8) begin
            counter <= counter + 1;
            if (valid_in) begin
                char_received <= 1;
                if (start_char == 0) begin
                    start_char <= char_in;
                end
                if (last_in) begin
                    last_char <= char_in;
                end
            end
        end else begin
            if (char_received && (start_char == last_char)) begin
                result <= 1;
            end else begin
                result <= 0;
            end
            done <= 1;
            counter <= 8; // hold the counter value
        end
    end
end
endmodule