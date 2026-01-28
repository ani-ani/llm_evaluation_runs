module delimiter_replacer(
    input clk,
    input rst_n,
    input start,
    input [7:0] input_str [0:15],
    input [3:0] length,
    output reg [7:0] output_str [0:15],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] counter;
    reg [3:0] current_length;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            counter <= 4'd0;
            current_length <= 4'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                end else begin
                    next_state = IDLE;
                end
            end

            PROCESSING: begin
                if (counter == current_length - 4'd1) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = PROCESSING;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Counter logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        counter <= 4'd0;
                        current_length <= length;
                    end
                end

                PROCESSING: begin
                    counter <= counter + 4'd1;
                end

                DONE_STATE: begin
                    counter <= 4'd0;
                end

                default: counter <= 4'd0;
            endcase
        end
    end

    // Output string processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all output_str elements to 0
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                output_str[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // Initialize output_str with input_str values
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            output_str[i] <= input_str[i];
                        end
                    end
                end

                PROCESSING: begin
                    // Replace delimiters in current position
                    if (input_str[counter] == 8'd32 || input_str[counter] == 8'd44 || input_str[counter] == 8'd46) begin
                        output_str[counter] <= 8'd58;
                    end else begin
                        output_str[counter] <= input_str[counter];
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                end

                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Done signal logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            if (state == DONE_STATE) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule