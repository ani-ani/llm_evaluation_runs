module SpaceToPercent20(
    input clk,
    input rst_n,
    input start,
    output reg done,
    input [7:0] input_str [0:15],
    input [3:0] input_len,
    output reg [7:0] output_str [0:23],
    output reg [4:0] output_len
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ_CHAR = 3'd1;
    localparam [2:0] WRITE_NORMAL = 3'd2;
    localparam [2:0] WRITE_SPACE_1 = 3'd3;
    localparam [2:0] WRITE_SPACE_2 = 3'd4;
    localparam [2:0] WRITE_SPACE_3 = 3'd5;
    localparam [2:0] COMPLETE = 3'd6;

    // Registers
    reg [2:0] state, next_state;
    reg [3:0] in_pos;  // Input position (0-15)
    reg [4:0] out_pos; // Output position (0-23)
    reg [3:0] remaining_input; // Remaining characters to process
    reg [2:0] space_write_counter; // Counter for writing %20 (0-2)
    reg [7:0] current_char; // Current character being processed
    reg start_prev; // To detect rising edge of start
    reg [6:0] cycle_count; // Safety counter (0-100)

    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            out_pos <= 5'd0;
            in_pos <= 4'd0;
            remaining_input <= 4'd0;
            space_write_counter <= 3'd0;
            current_char <= 8'd0;
            start_prev <= 1'b0;
            cycle_count <= 7'd0;
            output_len <= 5'd0;
            // Initialize output_str array to 0
            output_str[0] <= 8'd0;
            output_str[1] <= 8'd0;
            output_str[2] <= 8'd0;
            output_str[3] <= 8'd0;
            output_str[4] <= 8'd0;
            output_str[5] <= 8'd0;
            output_str[6] <= 8'd0;
            output_str[7] <= 8'd0;
            output_str[8] <= 8'd0;
            output_str[9] <= 8'd0;
            output_str[10] <= 8'd0;
            output_str[11] <= 8'd0;
            output_str[12] <= 8'd0;
            output_str[13] <= 8'd0;
            output_str[14] <= 8'd0;
            output_str[15] <= 8'd0;
            output_str[16] <= 8'd0;
            output_str[17] <= 8'd0;
            output_str[18] <= 8'd0;
            output_str[19] <= 8'd0;
            output_str[20] <= 8'd0;
            output_str[21] <= 8'd0;
            output_str[22] <= 8'd0;
            output_str[23] <= 8'd0;
        end else begin
            start_prev <= start;
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 7'd0;
                    if (start && !start_prev) begin
                        in_pos <= 4'd0;
                        out_pos <= 5'd0;
                        remaining_input <= input_len;
                        output_len <= 5'd0;
                        // Clear output buffer on start
                        output_str[0] <= 8'd0;
                        output_str[1] <= 8'd0;
                        output_str[2] <= 8'd0;
                        output_str[3] <= 8'd0;
                        output_str[4] <= 8'd0;
                        output_str[5] <= 8'd0;
                        output_str[6] <= 8'd0;
                        output_str[7] <= 8'd0;
                        output_str[8] <= 8'd0;
                        output_str[9] <= 8'd0;
                        output_str[10] <= 8'd0;
                        output_str[11] <= 8'd0;
                        output_str[12] <= 8'd0;
                        output_str[13] <= 8'd0;
                        output_str[14] <= 8'd0;
                        output_str[15] <= 8'd0;
                        output_str[16] <= 8'd0;
                        output_str[17] <= 8'd0;
                        output_str[18] <= 8'd0;
                        output_str[19] <= 8'd0;
                        output_str[20] <= 8'd0;
                        output_str[21] <= 8'd0;
                        output_str[22] <= 8'd0;
                        output_str[23] <= 8'd0;
                    end
                end

                READ_CHAR: begin
                    // Safety check for buffer overflow
                    if (out_pos > 5'd23) begin
                        state <= COMPLETE;
                    end else if (remaining_input == 4'd0) begin
                        state <= COMPLETE;
                    end else begin
                        current_char <= input_str[in_pos];
                    end
                end

                WRITE_NORMAL: begin
                    output_str[out_pos] <= current_char;
                    out_pos <= out_pos + 5'd1;
                    in_pos <= in_pos + 4'd1;
                    remaining_input <= remaining_input - 4'd1;
                end

                WRITE_SPACE_1: begin
                    output_str[out_pos] <= 8'h25; // '%'
                    out_pos <= out_pos + 5'd1;
                end

                WRITE_SPACE_2: begin
                    output_str[out_pos] <= 8'h32; // '2'
                    out_pos <= out_pos + 5'd1;
                end

                WRITE_SPACE_3: begin
                    output_str[out_pos] <= 8'h30; // '0'
                    out_pos <= out_pos + 5'd1;
                    in_pos <= in_pos + 4'd1;
                    remaining_input <= remaining_input - 4'd1;
                end

                COMPLETE: begin
                    done <= 1'b1;
                    output_len <= out_pos;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Cycle counter for safety (max 100 cycles)
            if (state != IDLE && state != COMPLETE && start_prev) begin
                if (cycle_count < 7'd100) begin
                    cycle_count <= cycle_count + 7'd1;
                end else begin
                    state <= COMPLETE; // Force completion
                end
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state; // Default
        
        case (state)
            IDLE: begin
                if (start && !start_prev) begin
                    if (input_len > 4'd0)
                        next_state = READ_CHAR;
                    else
                        next_state = COMPLETE; // Empty string
                end
            end

            READ_CHAR: begin
                if (out_pos > 5'd23 || remaining_input == 4'd0) begin
                    next_state = COMPLETE;
                end else begin
                    if (current_char == 8'h20) // Space character
                        next_state = WRITE_SPACE_1;
                    else
                        next_state = WRITE_NORMAL;
                end
            end

            WRITE_NORMAL: begin
                next_state = READ_CHAR;
            end

            WRITE_SPACE_1: begin
                next_state = WRITE_SPACE_2;
            end

            WRITE_SPACE_2: begin
                next_state = WRITE_SPACE_3;
            end

            WRITE_SPACE_3: begin
                next_state = READ_CHAR;
            end

            COMPLETE: begin
                // Stay here for one cycle, then return to IDLE if no start
                if (!start) begin
                    next_state = IDLE;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule