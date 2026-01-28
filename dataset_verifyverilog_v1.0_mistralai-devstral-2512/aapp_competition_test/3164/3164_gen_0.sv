module LongestSubArrayTwice(
    input clk,
    input rst_n,
    input start,
    input [15:0] arr [0:255],
    input [5:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] SETUP     = 3'd1;
    localparam [2:0] SCAN      = 3'd2;
    localparam [2:0] VALIDATE  = 3'd3;
    localparam [2:0] OPTIMIZE  = 3'd4;
    localparam [2:0] COMPLETE  = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [5:0] left_ptr, right_ptr;
    reg [5:0] max_length, current_length;
    reg [7:0] freq [0:255];
    reg [5:0] window_start;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd16384;

    // Frequency validation
    wire all_twice;
    reg [7:0] i;
    reg valid_flag;

    always @(*) begin
        valid_flag = 1'b1;
        for (i = 0; i < 256; i = i + 1) begin
            if (freq[i] != 8'd0 && freq[i] != 8'd2) begin
                valid_flag = 1'b0;
            end
        end
    end
    assign all_twice = valid_flag;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 16'd0;
            max_length <= 6'd0;
            current_length <= 6'd0;
            left_ptr <= 6'd0;
            right_ptr <= 6'd0;
            window_start <= 6'd0;
            for (i = 0; i < 256; i = i + 1) begin
                freq[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 16'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state = SETUP;
                    end else begin
                        next_state = IDLE;
                    end
                end

                SETUP: begin
                    // Initialize for new window
                    left_ptr <= window_start;
                    right_ptr <= window_start;
                    current_length <= 6'd0;
                    for (i = 0; i < 256; i = i + 1) begin
                        freq[i] <= 8'd0;
                    end
                    next_state = SCAN;
                end

                SCAN: begin
                    // Expand window to the right
                    if (right_ptr < len) begin
                        freq[arr[right_ptr]] <= freq[arr[right_ptr]] + 8'd1;
                        right_ptr <= right_ptr + 6'd1;
                        current_length <= current_length + 6'd1;
                        next_state = VALIDATE;
                    end else begin
                        next_state = COMPLETE;
                    end
                end

                VALIDATE: begin
                    if (all_twice) begin
                        next_state = OPTIMIZE;
                    end else begin
                        next_state = SCAN;
                    end
                end

                OPTIMIZE: begin
                    // Shrink window from left
                    if (left_ptr < right_ptr) begin
                        freq[arr[left_ptr]] <= freq[arr[left_ptr]] - 8'd1;
                        left_ptr <= left_ptr + 6'd1;
                        current_length <= current_length - 6'd1;
                        if (all_twice) begin
                            if (current_length > max_length) begin
                                max_length <= current_length;
                            end
                            next_state = OPTIMIZE;
                        end else begin
                            next_state = SCAN;
                        end
                    end else begin
                        if (current_length > max_length) begin
                            max_length <= current_length;
                        end
                        next_state = COMPLETE;
                    end
                end

                COMPLETE: begin
                    // Move to next starting position
                    window_start <= window_start + 6'd1;
                    if (window_start >= len) begin
                        result <= max_length;
                        done <= 1'b1;
                        next_state = IDLE;
                    end else begin
                        next_state = SETUP;
                    end
                end

                default: next_state = IDLE;
            endcase
        end
    end

    // Timeout protection
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES) begin
            result <= max_length;
            done <= 1'b1;
            state <= IDLE;
            cycle_count <= 16'd0;
        end
    end

endmodule