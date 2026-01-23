module replace_spaces(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    output reg char_read,
    output reg [7:0] char_out,
    output reg char_valid_out,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam READ_CHAR = 3'b001;
    localparam CHECK_SPACE = 3'b010;
    localparam OUTPUT_CHAR = 3'b011;
    localparam WAIT_FOR_NEXT = 3'b100;
    localparam FINISHED = 3'b101;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] current_char;
    reg space_mode;
    reg [1:0] output_counter; // 00='%', 01='0', 10='0'
    reg [3:0] position; // 0-15 max position
    reg done_flag;

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_char <= 8'b0;
            space_mode <= 1'b0;
            output_counter <= 2'b00;
            position <= 4'b0;
            done_flag <= 1'b0;
            char_read <= 1'b0;
            char_out <= 8'b0;
            char_valid_out <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            // Default outputs
            char_read <= 1'b0;
            char_valid_out <= 1'b0;
            done <= done_flag;

            case (state)
                IDLE: begin
                    if (start) begin
                        position <= 4'b0;
                        done_flag <= 1'b0;
                        space_mode <= 1'b0;
                        output_counter <= 2'b00;
                    end
                end

                READ_CHAR: begin
                    if (char_valid) begin
                        char_read <= 1'b1;
                        current_char <= char_in;
                    end
                end

                CHECK_SPACE: begin
                    // Just transition, check happens in combinational logic
                    if (current_char == 8'h20) begin
                        space_mode <= 1'b1;
                        output_counter <= 2'b00; // Start with '%'
                    end else begin
                        space_mode <= 1'b0;
                    end
                end

                OUTPUT_CHAR: begin
                    if (space_mode) begin
                        // Output '%20' sequence
                        char_valid_out <= 1'b1;
                        case (output_counter)
                            2'b00: begin
                                char_out <= 8'h25; // '%'
                                output_counter <= 2'b01;
                            end
                            2'b01: begin
                                char_out <= 8'h30; // '0'
                                output_counter <= 2'b10;
                            end
                            2'b10: begin
                                char_out <= 8'h30; // '0'
                                output_counter <= 2'b00;
                                position <= position + 1;
                                space_mode <= 1'b0;
                            end
                        endcase
                    end else begin
                        // Output single character
                        char_valid_out <= 1'b1;
                        char_out <= current_char;
                        position <= position + 1;
                    end
                end

                WAIT_FOR_NEXT: begin
                    // Check termination conditions
                    if (current_char == 8'h00 || position >= 15) begin
                        done_flag <= 1'b1;
                    end
                end

                FINISHED: begin
                    done_flag <= 1'b1;
                end
            endcase
        end
    end

    // Combinational next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = READ_CHAR;
                else next_state = IDLE;
            end

            READ_CHAR: begin
                if (char_valid) next_state = CHECK_SPACE;
                else next_state = READ_CHAR; // Wait for valid input
            end

            CHECK_SPACE: begin
                next_state = OUTPUT_CHAR;
            end

            OUTPUT_CHAR: begin
                if (space_mode && output_counter != 2'b10) begin
                    // Still outputting '%20' sequence
                    next_state = OUTPUT_CHAR;
                end else begin
                    next_state = WAIT_FOR_NEXT;
                end
            end

            WAIT_FOR_NEXT: begin
                if (current_char == 8'h00 || position >= 15) begin
                    next_state = FINISHED;
                end else begin
                    // Check if next char is available
                    if (char_valid) begin
                        next_state = READ_CHAR;
                    end else begin
                        next_state = WAIT_FOR_NEXT;
                    end
                end
            end

            FINISHED: begin
                if (!rst_n) next_state = IDLE;
                else next_state = FINISHED;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule