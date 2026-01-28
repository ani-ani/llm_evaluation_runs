module remove_consecutive_duplicates(
    input clk,
    input rst_n,
    input start,
    input [7:0] input_data [0:15],
    input [3:0] input_len,
    output reg [7:0] output_data [0:15],
    output reg [3:0] output_len,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] input_index;
    reg [3:0] output_index;
    reg [7:0] prev_value;
    reg [7:0] current_value;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd32;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            input_index <= 4'd0;
            output_index <= 4'd0;
            prev_value <= 8'd0;
            current_value <= 8'd0;
            cycle_count <= 4'd0;
            done <= 1'b0;
            output_len <= 4'd0;

            // Initialize output_data to all zeros
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                output_data[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 4'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        next_state <= PROCESS;
                        input_index <= 4'd0;
                        output_index <= 4'd0;
                        prev_value <= 8'd0;
                        current_value <= 8'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PROCESS: begin
                    // Read current input value
                    current_value <= input_data[input_index];

                    // First element is always included
                    if (input_index == 4'd0) begin
                        output_data[output_index] <= current_value;
                        output_index <= output_index + 4'd1;
                        prev_value <= current_value;
                    end else begin
                        // Compare with previous value
                        if (current_value != prev_value) begin
                            output_data[output_index] <= current_value;
                            output_index <= output_index + 4'd1;
                        end
                        prev_value <= current_value;
                    end

                    // Move to next input element
                    input_index <= input_index + 4'd1;

                    // Check if processing is complete
                    if (input_index >= input_len || cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                        output_len <= output_index;
                    end else begin
                        next_state <= PROCESS;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule