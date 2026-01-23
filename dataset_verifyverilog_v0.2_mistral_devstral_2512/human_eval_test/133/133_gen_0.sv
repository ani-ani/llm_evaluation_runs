module sum_squares (
    input clk,
    input rst_n,
    input start,
    input [4:0] num_elements,
    input [31:0] input_list [0:7],
    output reg [31:0] result,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        LOAD,
        CEIL,
        SQUARE,
        ACCUM,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [31:0] current_value;
    reg [31:0] ceiled_value;
    reg [31:0] squared_value;
    reg [31:0] accumulator;
    reg [2:0] element_counter;
    reg [31:0] temp_result;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            result <= 0;
            accumulator <= 0;
            element_counter <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            LOAD: next_state = CEIL;
            CEIL: next_state = SQUARE;
            SQUARE: next_state = ACCUM;
            ACCUM: begin
                if (element_counter == num_elements - 1) next_state = DONE;
                else next_state = LOAD;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_value <= 0;
            ceiled_value <= 0;
            squared_value <= 0;
            accumulator <= 0;
            element_counter <= 0;
            done <= 0;
            result <= 0;
        end else begin
            case (current_state)
                LOAD: begin
                    current_value <= input_list[element_counter];
                end
                CEIL: begin
                    // Ceiling operation
                    reg signed [31:0] signed_value = current_value;
                    reg [15:0] fractional = current_value[15:0];
                    reg [15:0] integer = current_value[31:16];
                    
                    if (signed_value[31] == 0) begin // Positive or zero
                        if (fractional > 0) begin
                            ceiled_value = {integer + 1, 16'h0};
                        end else begin
                            ceiled_value = current_value;
                        end
                    end else begin // Negative
                        if (fractional == 0) begin
                            ceiled_value = current_value;
                        end else begin
                            ceiled_value = current_value;
                        end
                    end
                end
                SQUARE: begin
                    // Square the ceiled value (17-bit integer part)
                    reg [16:0] int_part = ceiled_value[31:16];
                    reg [33:0] square = int_part * int_part;
                    squared_value = {square[33:17], square[16:0]}; // Convert back to Q16.16
                end
                ACCUM: begin
                    accumulator = accumulator + squared_value;
                    element_counter <= element_counter + 1;
                end
                DONE: begin
                    result <= accumulator;
                    done <= 1;
                end
            endcase
        end
    end

endmodule