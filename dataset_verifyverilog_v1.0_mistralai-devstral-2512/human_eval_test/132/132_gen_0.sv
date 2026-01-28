module bracket_detector(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_data,
    input char_valid,
    input char_done,
    output reg [1:0] result,
    output reg done,
    output reg ready
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] PROCESS   = 3'd1;
    localparam [2:0] COMPLETE  = 3'd2;

    // Stack and counters
    reg [2:0] stack_ptr;  // 3-bit pointer (max depth 8)
    reg [2:0] nest_count; // 3-bit nesting counter
    reg [2:0] max_depth;  // 3-bit max depth tracker
    reg [7:0] stack [0:7]; // Stack storage (8 entries)

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd64;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 2'd0;
            done <= 1'b0;
            ready <= 1'b1;
            stack_ptr <= 3'd0;
            nest_count <= 3'd0;
            max_depth <= 3'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    ready <= 1'b1;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                        ready <= 1'b0;
                        stack_ptr <= 3'd0;
                        nest_count <= 3'd0;
                        max_depth <= 3'd0;
                    end
                end

                PROCESS: begin
                    ready <= 1'b1;
                    cycle_count <= cycle_count + 8'd1;

                    if (char_valid) begin
                        // Process character
                        if (char_data == 8'd'[') begin
                            // Push to stack
                            if (stack_ptr < 8) begin
                                stack[stack_ptr] <= char_data;
                                stack_ptr <= stack_ptr + 3'd1;
                                nest_count <= nest_count + 3'd1;
                                if (nest_count > max_depth) begin
                                    max_depth <= nest_count;
                                end
                            end
                        end else if (char_data == 8'd']') begin
                            // Pop from stack
                            if (stack_ptr > 0) begin
                                stack_ptr <= stack_ptr - 3'd1;
                                nest_count <= nest_count - 3'd1;
                            end
                        end
                    end

                    // Check for completion
                    if (char_done || cycle_count >= MAX_CYCLES) begin
                        state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    // Determine result
                    if (stack_ptr == 0) begin
                        if (max_depth > 1) begin
                            result <= 2'd2;  // 10: nested
                        end else if (max_depth == 1) begin
                            result <= 2'd1;  // 01: no nesting
                        end else begin
                            result <= 2'd0;  // 00: invalid
                        end
                    end else begin
                        result <= 2'd0;  // 00: unbalanced
                    end

                    done <= 1'b1;
                    ready <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    result <= 2'd0;
                    done <= 1'b0;
                    ready <= 1'b1;
                end
            endcase
        end
    end

endmodule