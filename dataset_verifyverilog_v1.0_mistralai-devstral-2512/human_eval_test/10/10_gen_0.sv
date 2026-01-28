module shortest_palindrome(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] input_len,
    input wire [7:0] input_str [0:15],
    output reg [5:0] output_len,
    output reg [7:0] output_str [0:31],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_PALINDROME = 3'd1;
    localparam [2:0] FIND_SUFFIX = 3'd2;
    localparam [2:0] BUILD_OUTPUT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [4:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd128;

    // Internal registers for palindrome checking
    reg [4:0] check_index;
    reg is_palindrome;

    // Internal registers for suffix finding
    reg [4:0] suffix_len;
    reg [4:0] suffix_start;
    reg [4:0] suffix_check_index;
    reg [4:0] longest_suffix_len;

    // Internal registers for output building
    reg [4:0] build_index;
    reg [4:0] prefix_len;
    reg [4:0] reverse_index;

    // Reversed input string storage
    reg [7:0] reversed_str [0:15];

    // Initialize reversed string
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 16; i = i + 1) begin
                reversed_str[i] <= 8'd0;
            end
        end else if (state == IDLE && start) begin
            for (i = 0; i < 16; i = i + 1) begin
                reversed_str[i] <= input_str[15 - i];
            end
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 5'd0;
            check_index <= 5'd0;
            is_palindrome <= 1'b0;
            suffix_len <= 5'd0;
            suffix_start <= 5'd0;
            suffix_check_index <= 5'd0;
            longest_suffix_len <= 5'd0;
            build_index <= 5'd0;
            prefix_len <= 5'd0;
            reverse_index <= 5'd0;
            output_len <= 6'd0;
            done <= 1'b0;
            for (i = 0; i < 32; i = i + 1) begin
                output_str[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 5'd0;
                    if (start) begin
                        next_state <= CHECK_PALINDROME;
                        check_index <= 5'd0;
                        is_palindrome <= 1'b1;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECK_PALINDROME: begin
                    cycle_count <= cycle_count + 5'd1;
                    if (check_index < input_len) begin
                        if (input_str[check_index] != reversed_str[check_index]) begin
                            is_palindrome <= 1'b0;
                        end
                        check_index <= check_index + 5'd1;
                        if (check_index == input_len) begin
                            if (is_palindrome) begin
                                next_state <= BUILD_OUTPUT;
                                prefix_len <= 5'd0;
                            end else begin
                                next_state <= FIND_SUFFIX;
                                suffix_len <= input_len - 5'd1;
                                suffix_start <= 5'd0;
                                longest_suffix_len <= 5'd0;
                            end
                        end else begin
                            next_state <= CHECK_PALINDROME;
                        end
                    end else begin
                        next_state <= CHECK_PALINDROME;
                    end
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                    end
                end

                FIND_SUFFIX: begin
                    cycle_count <= cycle_count + 5'd1;
                    if (suffix_len > 5'd0) begin
                        if (suffix_check_index < suffix_len) begin
                            if (input_str[suffix_start + suffix_check_index] != input_str[suffix_start + suffix_len - 5'd1 - suffix_check_index]) begin
                                suffix_start <= suffix_start + 5'd1;
                                suffix_len <= suffix_len - 5'd1;
                                suffix_check_index <= 5'd0;
                            end else begin
                                suffix_check_index <= suffix_check_index + 5'd1;
                                if (suffix_check_index == suffix_len) begin
                                    longest_suffix_len <= suffix_len;
                                    suffix_start <= suffix_start + 5'd1;
                                    suffix_len <= suffix_len - 5'd1;
                                    suffix_check_index <= 5'd0;
                                end
                            end
                        end else begin
                            next_state <= FIND_SUFFIX;
                        end
                    end else begin
                        prefix_len <= input_len - longest_suffix_len;
                        next_state <= BUILD_OUTPUT;
                    end
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                    end
                end

                BUILD_OUTPUT: begin
                    cycle_count <= cycle_count + 5'd1;
                    if (build_index < input_len) begin
                        output_str[build_index] <= input_str[build_index];
                        build_index <= build_index + 5'd1;
                        if (build_index == input_len) begin
                            if (prefix_len > 5'd0) begin
                                reverse_index <= 5'd0;
                            end else begin
                                output_len <= input_len;
                                next_state <= DONE_STATE;
                            end
                        end
                    end else if (reverse_index < prefix_len) begin
                        output_str[input_len + reverse_index] <= input_str[prefix_len - 5'd1 - reverse_index];
                        reverse_index <= reverse_index + 5'd1;
                        if (reverse_index == prefix_len) begin
                            output_len <= input_len + prefix_len;
                            next_state <= DONE_STATE;
                        end
                    end else begin
                        next_state <= DONE_STATE;
                    end
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
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