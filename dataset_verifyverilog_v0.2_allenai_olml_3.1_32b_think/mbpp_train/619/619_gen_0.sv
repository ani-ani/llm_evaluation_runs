module move_num (input clk, input rst_n, input start, input [7:0] char_in, input valid_in, output reg [7:0] char_out, output reg valid_out, output reg done);
reg [2:0] state;
reg [4:0] input_count;
reg [4:0] non_digit_count;
reg [4:0] digit_count;
reg [7:0] non_digit_buf [15:0];
reg [7:0] digit_buf [15:0];
reg [3:0] non_digit_ptr;
reg [3:0] digit_ptr;
reg done;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 3'b000;
        input_count <=5'd0;
        non_digit_count <=5'd0;
        digit_count <=5'd0;
        non_digit_ptr <=4'd0;
        digit_ptr <=4'd0;
        done <=1'b0;
    end else begin
        case(state)
            3'b000: begin
                char_out <= 8'b0;
                valid_out <=1'b0;
                if (start) begin
                    state <= 3'b001;
                    input_count <=5'd0;
                    non_digit_count <=5'd0;
                    digit_count <=5'd0;
                    non_digit_ptr <=4'd0;
                    digit_ptr <=4'd0;
                end else begin
                    state <=3'b000;
                end
            end
            3'b001: begin
                char_out <=8'b0;
                valid_out <=1'b0;
                if (valid_in && input_count <16) begin
                    input_count <= input_count +1;
                    if (char_in >=8'h30 && char_in <=8'h39) begin
                        digit_buf[digit_count] <= char_in;
                        digit_count <= digit_count +1;
                    end else begin
                        non_digit_buf[non_digit_count] <= char_in;
                        non_digit_count <= non_digit_count +1;
                    end
                end
                if (input_count ==16) begin
                    state <=3'b010;
                end else begin
                    state <=3'b001;
                end
            end
            3'b010: begin
                if (non_digit_ptr < non_digit_count) begin
                    char_out <= non_digit_buf[non_digit_ptr];
                    valid_out <=1'b1;
                    non_digit_ptr <= non_digit_ptr +1;
                    state <=3'b010;
                end else begin
                    state <=3'b011;
                    valid_out <=1'b0;
                    char_out <=8'b0;
                end
            end
            3'b011: begin
                if (digit_ptr < digit_count) begin
                    char_out <= digit_buf[digit_ptr];
                    valid_out <=1'b1;
                    digit_ptr <= digit_ptr +1;
                    state <=3'b011;
                end else begin
                    state <=3'b100;
                    valid_out <=1'b0;
                    char_out <=8'b0;
                    done <=1'b1;
                end
            end
            3'b100: begin
                done <=1'b1;
                char_out <=8'b0;
                valid_out <=1'b0;
                state <=3'b100;
            end
            default: begin
                char_out <=8'b0;
                valid_out <=1'b0;
                done <=1'b0;
                state <=3'b000;
            end
        endcase
    end
endmodule