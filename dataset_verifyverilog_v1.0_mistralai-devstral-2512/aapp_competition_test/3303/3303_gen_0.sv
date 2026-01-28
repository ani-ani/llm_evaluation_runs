module petra_add(
    input clk,
    input rst_n,
    input start,
    input [7:0] a_str [0:15],
    input [7:0] b_str [0:15],
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] PARSE_A   = 3'd1;
    localparam [2:0] PARSE_B   = 3'd2;
    localparam [2:0] CALCULATE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [15:0] val_a, val_b;
    reg [3:0] digit_index;
    reg [31:0] cycle_count;
    localparam [31:0] MAX_CYCLES = 32'd1000;

    // Parse ASCII digit to value
    function [3:0] ascii_to_digit(input [7:0] ascii_char);
        case (ascii_char)
            8'd48: ascii_to_digit = 4'd0;
            8'd49: ascii_to_digit = 4'd1;
            8'd50: ascii_to_digit = 4'd2;
            8'd51: ascii_to_digit = 4'd3;
            8'd52: ascii_to_digit = 4'd4;
            8'd53: ascii_to_digit = 4'd5;
            8'd54: ascii_to_digit = 4'd6;
            8'd55: ascii_to_digit = 4'd7;
            8'd56: ascii_to_digit = 4'd8;
            8'd57: ascii_to_digit = 4'd9;
            default: ascii_to_digit = 4'd0;
        endcase
    endfunction

    // Compute minimal steps
    function [31:0] compute_min_steps(input [15:0] a, input [15:0] b);
        reg [15:0] larger, smaller;
        reg [31:0] k, temp_sum, carry, digit_a, digit_b, digit_sum;
        reg [3:0] i;
        
        if (a >= b) begin
            larger = a;
            smaller = b;
        end else begin
            larger = b;
            smaller = a;
        end
        
        k = 32'd0;
        carry = 32'd0;
        
        for (i = 0; i < 16; i = i + 1) begin
            digit_a = larger[4*i +: 4];
            digit_b = smaller[4*i +: 4];
            digit_sum = digit_a + digit_b + carry;
            
            if (digit_sum >= 10) begin
                carry = 32'd1;
                k = k + (32'd10 - (digit_sum % 32'd10)) * (32'd1 << (4*i));
            end else begin
                carry = 32'd0;
            end
        end
        
        compute_min_steps = k;
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            val_a <= 16'd0;
            val_b <= 16'd0;
            digit_index <= 4'd0;
            cycle_count <= 32'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 32'd0;
                    if (start) begin
                        next_state = PARSE_A;
                    end else begin
                        next_state = IDLE;
                    end
                end
                
                PARSE_A: begin
                    if (digit_index < 16) begin
                        val_a <= val_a + (ascii_to_digit(a_str[digit_index]) << (4*digit_index));
                        digit_index <= digit_index + 4'd1;
                        next_state = PARSE_A;
                    end else begin
                        digit_index <= 4'd0;
                        next_state = PARSE_B;
                    end
                end
                
                PARSE_B: begin
                    if (digit_index < 16) begin
                        val_b <= val_b + (ascii_to_digit(b_str[digit_index]) << (4*digit_index));
                        digit_index <= digit_index + 4'd1;
                        next_state = PARSE_B;
                    end else begin
                        digit_index <= 4'd0;
                        next_state = CALCULATE;
                    end
                end
                
                CALCULATE: begin
                    cycle_count <= cycle_count + 32'd1;
                    result <= compute_min_steps(val_a, val_b);
                    next_state = DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    next_state = IDLE;
                end
                
                default: next_state = IDLE;
            endcase
        end
    end

endmodule