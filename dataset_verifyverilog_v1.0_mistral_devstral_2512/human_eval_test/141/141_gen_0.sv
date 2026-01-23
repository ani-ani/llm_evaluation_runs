module file_name_check(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [3:0] char_idx,
    input valid_char,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] VALIDATING = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state;
    reg [1:0] digit_count;
    reg [0:0] dot_count;
    reg [0:0] first_char_valid;
    reg [0:0] found_dot;
    reg [1:0] extension_length;
    reg [23:0] ext_buffer;
    reg [3:0] char_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            digit_count <= 2'd0;
            dot_count <= 1'b0;
            first_char_valid <= 1'b0;
            found_dot <= 1'b0;
            extension_length <= 2'd0;
            ext_buffer <= 24'd0;
            char_counter <= 4'd0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESSING;
                        char_counter <= 4'd0;
                        digit_count <= 2'd0;
                        dot_count <= 1'b0;
                        first_char_valid <= 1'b0;
                        found_dot <= 1'b0;
                        extension_length <= 2'd0;
                        ext_buffer <= 24'd0;
                    end
                end

                PROCESSING: begin
                    if (valid_char) begin
                        // Process current character
                        if (char_in >= 8'd48 && char_in <= 8'd57) begin
                            digit_count <= digit_count + 1'b1;
                        end

                        if (char_in == 8'd46) begin
                            dot_count <= dot_count + 1'b1;
                            found_dot <= 1'b1;
                            extension_length <= 2'd0;
                        end

                        if (char_idx == 4'd0) begin
                            if ((char_in >= 8'd65 && char_in <= 8'd90) || (char_in >= 8'd97 && char_in <= 8'd122)) begin
                                first_char_valid <= 1'b1;
                            end
                        end

                        if (found_dot && extension_length < 2'd3) begin
                            ext_buffer[(extension_length * 8) +: 8] <= char_in;
                            extension_length <= extension_length + 1'b1;
                        end

                        char_counter <= char_counter + 1'b1;

                        if (char_counter == 4'd15) begin
                            state <= VALIDATING;
                        end
                    end
                end

                VALIDATING: begin
                    // Validate all conditions
                    reg [0:0] valid_extension;
                    reg [0:0] ext_txt;
                    reg [0:0] ext_exe;
                    reg [0:0] ext_dll;

                    // Check for "txt"
                    ext_txt = (ext_buffer[7:0] == 8'd116 && ext_buffer[15:8] == 8'd120 && ext_buffer[23:16] == 8'd116);
                    // Check for "exe"
                    ext_exe = (ext_buffer[7:0] == 8'd101 && ext_buffer[15:8] == 8'd120 && ext_buffer[23:16] == 8'd101);
                    // Check for "dll"
                    ext_dll = (ext_buffer[7:0] == 8'd108 && ext_buffer[15:8] == 8'd108 && ext_buffer[23:16] == 8'd100);

                    valid_extension = ext_txt || ext_exe || ext_dll;

                    result <= (digit_count <= 2'd3) && (dot_count == 1'b1) && first_char_valid && valid_extension;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule