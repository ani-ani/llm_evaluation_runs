module fix_spaces(
    input clk,
    input rst_n,
    input start,
    input [7:0] text [0:7],
    input [3:0] length,
    output reg [7:0] result [0:7],
    output reg [3:0] out_len,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CAPTURE = 2'd1;
    localparam [1:0] PROCESSING = 2'd2;
    localparam [1:0] FINISHED = 2'd3;

    reg [1:0] state;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd12;

    // Internal registers for processing
    reg [7:0] captured_text [0:7];
    reg [3:0] captured_length;
    reg [3:0] in_index;
    reg [3:0] out_index;
    reg [3:0] space_counter;
    reg space_active;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 4'd0;
            done <= 1'b0;
            out_len <= 4'd0;
            in_index <= 4'd0;
            out_index <= 4'd0;
            space_counter <= 4'd0;
            space_active <= 1'b0;

            // Initialize result array
            result[0] <= 8'd0;
            result[1] <= 8'd0;
            result[2] <= 8'd0;
            result[3] <= 8'd0;
            result[4] <= 8'd0;
            result[5] <= 8'd0;
            result[6] <= 8'd0;
            result[7] <= 8'd0;

            // Initialize captured_text array
            captured_text[0] <= 8'd0;
            captured_text[1] <= 8'd0;
            captured_text[2] <= 8'd0;
            captured_text[3] <= 8'd0;
            captured_text[4] <= 8'd0;
            captured_text[5] <= 8'd0;
            captured_text[6] <= 8'd0;
            captured_text[7] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= CAPTURE;
                    end
                end

                CAPTURE: begin
                    // Capture input data
                    captured_text[0] <= text[0];
                    captured_text[1] <= text[1];
                    captured_text[2] <= text[2];
                    captured_text[3] <= text[3];
                    captured_text[4] <= text[4];
                    captured_text[5] <= text[5];
                    captured_text[6] <= text[6];
                    captured_text[7] <= text[7];
                    captured_length <= length;

                    // Initialize processing variables
                    in_index <= 4'd0;
                    out_index <= 4'd0;
                    space_counter <= 4'd0;
                    space_active <= 1'b0;

                    state <= PROCESSING;
                    cycle_count <= cycle_count + 4'd1;
                end

                PROCESSING: begin
                    cycle_count <= cycle_count + 4'd1;

                    // Process characters
                    if (in_index < captured_length) begin
                        if (captured_text[in_index] == 8'd32) begin
                            // Space character
                            space_counter <= space_counter + 4'd1;
                            space_active <= 1'b1;
                        end else begin
                            // Non-space character
                            // Handle spaces before this character
                            if (space_active) begin
                                if (space_counter == 4'd1) begin
                                    // Single space -> underscore
                                    result[out_index] <= 8'd95;
                                    out_index <= out_index + 4'd1;
                                end else if (space_counter > 4'd2) begin
                                    // More than 2 spaces -> hyphen
                                    result[out_index] <= 8'd45;
                                    out_index <= out_index + 4'd1;
                                end else begin
                                    // Exactly 2 spaces -> two underscores
                                    result[out_index] <= 8'd95;
                                    out_index <= out_index + 4'd1;
                                    result[out_index] <= 8'd95;
                                    out_index <= out_index + 4'd1;
                                end
                                space_counter <= 4'd0;
                                space_active <= 1'b0;
                            end

                            // Write current character
                            result[out_index] <= captured_text[in_index];
                            out_index <= out_index + 4'd1;
                        end

                        in_index <= in_index + 4'd1;

                        // Check if processing is complete
                        if (in_index >= captured_length - 4'd1) begin
                            state <= FINISHED;
                        end
                    end else begin
                        // Handle trailing spaces
                        if (space_active) begin
                            if (space_counter == 4'd1) begin
                                result[out_index] <= 8'd95;
                                out_index <= out_index + 4'd1;
                            end else if (space_counter > 4'd2) begin
                                result[out_index] <= 8'd45;
                                out_index <= out_index + 4'd1;
                            end else begin
                                result[out_index] <= 8'd95;
                                out_index <= out_index + 4'd1;
                                result[out_index] <= 8'd95;
                                out_index <= out_index + 4'd1;
                            end
                        end
                        state <= FINISHED;
                    end
                end

                FINISHED: begin
                    if (cycle_count >= MAX_CYCLES) begin
                        done <= 1'b1;
                        out_len <= out_index;
                        state <= IDLE;
                    end else begin
                        cycle_count <= cycle_count + 4'd1;
                    end
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                end
            endcase
        end
    end

endmodule