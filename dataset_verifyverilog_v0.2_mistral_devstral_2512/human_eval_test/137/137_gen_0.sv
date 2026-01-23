module compare_one (
    input clk,
    input rst_n,
    input start,
    input [1:0] type_a,
    input [1:0] type_b,
    input [31:0] data_a,
    input [31:0] data_b,
    output reg [1:0] result_type,
    output reg [31:0] result_data,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        PARSE_A,
        PARSE_B,
        COMPARE,
        DONE
    } state_t;

    state_t state;
    reg [31:0] value_a_q16;
    reg [31:0] value_b_q16;
    reg [31:0] original_a;
    reg [31:0] original_b;
    reg [1:0] original_type_a;
    reg [1:0] original_type_b;
    reg [31:0] string_a;
    reg [31:0] string_b;
    reg [31:0] parsed_a;
    reg [31:0] parsed_b;
    reg [31:0] counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            value_a_q16 <= 0;
            value_b_q16 <= 0;
            original_a <= 0;
            original_b <= 0;
            original_type_a <= 0;
            original_type_b <= 0;
            string_a <= 0;
            string_b <= 0;
            parsed_a <= 0;
            parsed_b <= 0;
            counter <= 0;
            result_type <= 0;
            result_data <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PARSE_A;
                        original_a <= data_a;
                        original_b <= data_b;
                        original_type_a <= type_a;
                        original_type_b <= type_b;
                        counter <= 0;
                    end
                end
                PARSE_A: begin
                    case (original_type_a)
                        2'b00: value_a_q16 <= $signed(original_a) << 16; // Integer to Q16.16
                        2'b01: value_a_q16 <= original_a; // Already Q16.16
                        2'b10: begin
                            // String parsing (simplified for simulation)
                            // Assume data_a is the integer representation of the string
                            // e.g., "123" = 123, "1.2" = 12 (representing 1.2 as 12)
                            // For simulation, we'll treat it as a fixed-point value
                            // where the integer part is the whole number and the fractional part is the remainder
                            // For example, 123 -> 123.0, 12 -> 1.2 (if we assume 1 decimal place)
                            // Here, we'll assume the input is scaled by 10 for the fractional part
                            // So 123 -> 1230 (123.0), 12 -> 12 (1.2)
                            // But to convert to Q16.16, we need to scale it properly
                            // For simplicity, we'll assume the input is already in a format where
                            // the integer part is in the upper bits and the fractional part is in the lower bits
                            // For example, 123 -> 123 << 16, 12 -> (1 << 16) + (2 << 15) (but this is not accurate)
                            // For the sake of this example, we'll assume the input is the integer part
                            // and the fractional part is zero
                            value_a_q16 <= original_a << 16;
                        end
                    endcase
                    state <= PARSE_B;
                end
                PARSE_B: begin
                    case (original_type_b)
                        2'b00: value_b_q16 <= $signed(original_b) << 16; // Integer to Q16.16
                        2'b01: value_b_q16 <= original_b; // Already Q16.16
                        2'b10: begin
                            // Similar to PARSE_A
                            value_b_q16 <= original_b << 16;
                        end
                    endcase
                    state <= COMPARE;
                end
                COMPARE: begin
                    if (value_a_q16 > value_b_q16) begin
                        result_type <= original_type_a;
                        result_data <= original_a;
                    end else if (value_a_q16 < value_b_q16) begin
                        result_type <= original_type_b;
                        result_data <= original_b;
                    end else begin
                        result_type <= 2'b11; // Equal
                        result_data <= 0;
                    end
                    state <= DONE;
                end
                DONE: begin
                    done <= 1;
                    if (counter == 10) begin
                        done <= 0;
                        state <= IDLE;
                    end else begin
                        counter <= counter + 1;
                    end
                end
            endcase
        end
    end

endmodule