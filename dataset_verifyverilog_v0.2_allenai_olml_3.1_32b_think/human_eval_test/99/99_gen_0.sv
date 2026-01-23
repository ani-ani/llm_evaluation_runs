module closest_integer(input clk, input rst_n, input start, input [7:0][7:0] str_data, output reg [15:0] result, output reg done);
localparam IDLE = 3'd0;
localparam PARSE_SIGN = 3'd1;
localparam PARSE_INT = 3'd2;
localparam PARSE_FRAC = 3'd3;
localparam CALCULATE = 3'd4;
localparam ROUND = 3'd5;
localparam DONE_STATE = 3'd6;

reg [2:0] state, next_state;
reg [7:0] current_index =0;
reg [31:0] integer_value =0;
reg [31:0] fractional_num =0;
reg [2:0] frac_digits_count =0;
reg sign =0;
reg [15:0] result_reg;
reg done_flag =0;
reg round_flag_reg;

always @(*) begin
    case (frac_digits_count)
        1: threshold =5;
        2: threshold =50;
        3: threshold =500;
        4: threshold =5000;
        5: threshold =50000;
        6: threshold =500000;
        default: threshold =0;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        current_index <=0;
        integer_value <=0;
        fractional_num <=0;
        frac_digits_count <=0;
        sign <=0;
        result_reg <=0;
        done_flag <=0;
        round_flag_reg <=0;
    end else begin
        state <= next_state;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PARSE_SIGN;
                end else begin
                    next_state = IDLE;
                end
            end
            PARSE_SIGN: begin
                reg [7:0] first_char = str_data[current_index];
                if (first_char == 8'd45) begin
                    sign =1;
                    current_index <= current_index +1;
                    next_state = PARSE_INT;
                end else if (first_char >=8'd48 && first_char <=8'd57) begin
                    sign =0;
                    next_state = PARSE_INT;
                end else begin
                    integer_value <=0;
                    fractional_num <=0;
                    frac_digits_count <=0;
                    current_index <=8;
                    next_state = CALCULATE;
                end
            end
            PARSE_INT: begin
                reg [7:0] ch = str_data[current_index];
                if (current_index >=8) begin
                    next_state = CALCULATE;
                end else if (ch >=8'd48 && ch <=8'd57) begin
                    integer_value <= integer_value *10 + (ch - 8'd48);
                    current_index <= current_index +1;
                    next_state = PARSE_INT;
                end else if (ch ==8'd46) begin
                    current_index <= current_index +1;
                    next_state = PARSE_FRAC;
                end else begin
                    next_state = CALCULATE;
                end
            end
            PARSE_FRAC: begin
                if (current_index >=8) begin
                    next_state = CALCULATE;
                end else begin
                    reg [7:0] ch = str_data[current_index];
                    if (ch >=8'd48 && ch <=8'd57) begin
                        fractional_num <= fractional_num *10 + (ch -8'd48);
                        frac_digits_count <= frac_digits_count +1;
                        current_index <= current_index +1;
                        next_state = PARSE_FRAC;
                    end else begin
                        next_state = CALCULATE;
                    end
                end
            end
            CALCULATE: begin
                if (frac_digits_count >0) begin
                    round_flag_reg = fractional_num >= threshold;
                end else begin
                    round_flag_reg =0;
                end
                next_state = ROUND;
            end
            ROUND: begin
                if (round_flag_reg) begin
                    result_reg <= (sign) ? - (integer_value +1) : (integer_value +1);
                end else begin
                    result_reg <= (sign) ? -integer_value : integer_value;
                end
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                done_flag <=1;
                next_state = DONE_STATE;
            end
        endcase
    end
end

assign result = result_reg;
assign done = done_flag;

endmodule