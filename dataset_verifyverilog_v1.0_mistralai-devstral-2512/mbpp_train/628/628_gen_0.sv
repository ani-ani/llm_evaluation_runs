module space_replacer(
    input wire clk,
    input wire rst_n,
    input wire start,
    output reg done,
    input wire [7:0] input_str [0:15],
    input wire [3:0] input_len,
    output reg [7:0] output_str [0:23],
    output reg [4:0] output_len
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] READ_CHAR = 2'd1;
    localparam [1:0] WRITE_OUTPUT = 2'd2;
    localparam [1:0] COMPLETE = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] input_ptr;
    reg [4:0] output_ptr;
    reg [7:0] current_char;
    reg [7:0] temp_output [0:23];
    reg [4:0] temp_output_len;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            input_ptr <= 4'd0;
            output_ptr <= 5'd0;
            current_char <= 8'd0;
            temp_output_len <= 5'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            output_len <= 5'd0;
            // Initialize output_str to all zeros
            integer i;
            for (i = 0; i < 24; i = i + 1) begin
                output_str[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            if (state == READ_CHAR) begin
                current_char <= input_str[input_ptr];
            end
            if (state == WRITE_OUTPUT) begin
                if (current_char == 8'h20) begin
                    temp_output[output_ptr] <= 8'h25;
                    temp_output[output_ptr + 5'd1] <= 8'h32;
                    temp_output[output_ptr + 5'd2] <= 8'h30;
                    output_ptr <= output_ptr + 5'd3;
                    temp_output_len <= temp_output_len + 5'd3;
                end else begin
                    temp_output[output_ptr] <= current_char;
                    output_ptr <= output_ptr + 5'd1;
                    temp_output_len <= temp_output_len + 5'd1;
                end
            end
            if (state == COMPLETE) begin
                output_len <= temp_output_len;
                // Copy temp_output to output_str
                integer i;
                for (i = 0; i < 24; i = i + 1) begin
                    output_str[i] <= temp_output[i];
                end
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = READ_CHAR;
                    input_ptr = 4'd0;
                    output_ptr = 5'd0;
                    temp_output_len = 5'd0;
                    cycle_count = 8'd0;
                end
            end
            READ_CHAR: begin
                if (input_ptr < input_len) begin
                    next_state = WRITE_OUTPUT;
                end else begin
                    next_state = COMPLETE;
                end
            end
            WRITE_OUTPUT: begin
                if (current_char == 8'h20) begin
                    if (output_ptr + 5'd3 < 5'd24) begin
                        next_state = READ_CHAR;
                        input_ptr = input_ptr + 4'd1;
                    end else begin
                        next_state = COMPLETE;
                    end
                end else begin
                    if (output_ptr + 5'd1 < 5'd24) begin
                        next_state = READ_CHAR;
                        input_ptr = input_ptr + 4'd1;
                    end else begin
                        next_state = COMPLETE;
                    end
                end
            end
            COMPLETE: begin
                next_state = IDLE;
                done = 1'b1;
            end
            default: next_state = IDLE;
        endcase
    end

    // Cycle counter to prevent infinite loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else if (state != IDLE && state != COMPLETE) begin
            if (cycle_count < MAX_CYCLES) begin
                cycle_count <= cycle_count + 8'd1;
            end else begin
                cycle_count <= 8'd0;
                next_state = COMPLETE;
            end
        end
    end

endmodule