module ascii_to_upper (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_0,
    input wire [7:0] char_1,
    input wire [7:0] char_2,
    input wire [7:0] char_3,
    input wire [7:0] char_4,
    input wire [7:0] char_5,
    input wire [7:0] char_6,
    input wire [7:0] char_7,
    input wire [3:0] length,
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg [7:0] result_3,
    output reg [7:0] result_4,
    output reg [7:0] result_5,
    output reg [7:0] result_6,
    output reg [7:0] result_7,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] PROCESS   = 3'd1;
    localparam [2:0] FINISH    = 3'd2;
    localparam [2:0] RESET_OUT = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] index;
    reg [7:0] input_buffer [0:7];
    reg [3:0] valid_length;
    integer i;

    // Combinational logic for conversion
    wire [7:0] current_char;
    wire [7:0] converted_char;

    assign current_char = input_buffer[index];
    assign converted_char = (current_char >= 8'h61 && current_char <= 8'h7A) ? 
                           (current_char - 8'h20) : current_char;

    // FSM: State transition
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESS;
                else
                    next_state = IDLE;
            end
            PROCESS: begin
                if (index >= valid_length && valid_length > 4'd0)
                    next_state = FINISH;
                else if (valid_length == 4'd0)
                    next_state = FINISH;
                else
                    next_state = PROCESS;
            end
            FINISH: begin
                next_state = IDLE;
            end
            RESET_OUT: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // FSM: Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            valid_length <= 4'd0;
            done <= 1'b0;
            // Initialize output buffer
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            result_4 <= 8'd0;
            result_5 <= 8'd0;
            result_6 <= 8'd0;
            result_7 <= 8'd0;
            // Initialize input buffer
            input_buffer[0] <= 8'd0;
            input_buffer[1] <= 8'd0;
            input_buffer[2] <= 8'd0;
            input_buffer[3] <= 8'd0;
            input_buffer[4] <= 8'd0;
            input_buffer[5] <= 8'd0;
            input_buffer[6] <= 8'd0;
            input_buffer[7] <= 8'd0;
        end else begin
            state <= next_state;

            case (next_state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 4'd0;
                    if (start) begin
                        // Load input buffer
                        input_buffer[0] <= char_0;
                        input_buffer[1] <= char_1;
                        input_buffer[2] <= char_2;
                        input_buffer[3] <= char_3;
                        input_buffer[4] <= char_4;
                        input_buffer[5] <= char_5;
                        input_buffer[6] <= char_6;
                        input_buffer[7] <= char_7;
                        valid_length <= length;
                    end
                end

                PROCESS: begin
                    if (index < valid_length && index < 4'd8) begin
                        // Convert and store character
                        case (index)
                            4'd0: result_0 <= converted_char;
                            4'd1: result_1 <= converted_char;
                            4'd2: result_2 <= converted_char;
                            4'd3: result_3 <= converted_char;
                            4'd4: result_4 <= converted_char;
                            4'd5: result_5 <= converted_char;
                            4'd6: result_6 <= converted_char;
                            4'd7: result_7 <= converted_char;
                            default: begin
                                result_0 <= result_0;
                                result_1 <= result_1;
                                result_2 <= result_2;
                                result_3 <= result_3;
                                result_4 <= result_4;
                                result_5 <= result_5;
                                result_6 <= result_6;
                                result_7 <= result_7;
                            end
                        endcase
                        index <= index + 4'd1;
                    end else if (index < 4'd8) begin
                        // Fill remaining positions with zero
                        case (index)
                            4'd0: result_0 <= 8'd0;
                            4'd1: result_1 <= 8'd0;
                            4'd2: result_2 <= 8'd0;
                            4'd3: result_3 <= 8'd0;
                            4'd4: result_4 <= 8'd0;
                            4'd5: result_5 <= 8'd0;
                            4'd6: result_6 <= 8'd0;
                            4'd7: result_7 <= 8'd0;
                            default: begin
                                result_0 <= result_0;
                                result_1 <= result_1;
                                result_2 <= result_2;
                                result_3 <= result_3;
                                result_4 <= result_4;
                                result_5 <= result_5;
                                result_6 <= result_6;
                                result_7 <= result_7;
                            end
                        endcase
                        index <= index + 4'd1;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    index <= 4'd0;
                    valid_length <= 4'd0;
                end

                RESET_OUT: begin
                    result_0 <= 8'd0;
                    result_1 <= 8'd0;
                    result_2 <= 8'd0;
                    result_3 <= 8'd0;
                    result_4 <= 8'd0;
                    result_5 <= 8'd0;
                    result_6 <= 8'd0;
                    result_7 <= 8'd0;
                    done <= 1'b0;
                    index <= 4'd0;
                    valid_length <= 4'd0;
                    // Clear input buffer
                    input_buffer[0] <= 8'd0;
                    input_buffer[1] <= 8'd0;
                    input_buffer[2] <= 8'd0;
                    input_buffer[3] <= 8'd0;
                    input_buffer[4] <= 8'd0;
                    input_buffer[5] <= 8'd0;
                    input_buffer[6] <= 8'd0;
                    input_buffer[7] <= 8'd0;
                end

                default: begin
                    state <= IDLE;
                    index <= 4'd0;
                    valid_length <= 4'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule