module digit_sum(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] index;          // 0-7 for 8 elements
    reg [15:0] accumulator;
    reg negative_flag;
    reg process_done;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            index <= 4'd0;
            accumulator <= 16'd0;
            negative_flag <= 1'b0;
            process_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 4'd0;
                    accumulator <= 16'd0;
                    negative_flag <= 1'b0;
                    process_done <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                    end
                end

                PROCESS: begin
                    if (index < 4'd8) begin
                        // Process current element
                        case (arr[index])
                            8'h30, 8'h31, 8'h32, 8'h33, 8'h34,
                            8'h35, 8'h36, 8'h37, 8'h38, 8'h39: begin
                                // ASCII digit '0'-'9'
                                if (negative_flag) begin
                                    // Negative handling: for this spec, we treat '-' as skip
                                    // So we just add positive digit value
                                    accumulator <= accumulator + (arr[index] - 8'h30);
                                end else begin
                                    accumulator <= accumulator + (arr[index] - 8'h30);
                                end
                                negative_flag <= 1'b0; // Clear flag after using
                            end
                            8'h2D: begin // ASCII '-'
                                // Set negative flag for next digit
                                negative_flag <= 1'b1;
                            end
                            8'h2B: begin // ASCII '+'
                                // Clear negative flag
                                negative_flag <= 1'b0;
                            end
                            8'h61, 8'h62, 8'h63, 8'h64, 8'h65, 8'h66, 8'h67, 8'h68,
                            8'h69, 8'h6A, 8'h6B, 8'h6C, 8'h6D, 8'h6E, 8'h6F,
                            8'h70, 8'h71, 8'h72, 8'h73, 8'h74, 8'h75, 8'h76, 8'h77,
                            8'h78, 8'h79, 8'h7A,
                            8'h41, 8'h42, 8'h43, 8'h44, 8'h45, 8'h46, 8'h47, 8'h48,
                            8'h49, 8'h4A, 8'h4B, 8'h4C, 8'h4D, 8'h4E, 8'h4F,
                            8'h50, 8'h51, 8'h52, 8'h53, 8'h54, 8'h55, 8'h56, 8'h57,
                            8'h58, 8'h59, 8'h5A: begin
                                // Skip non-digit letters (a-z, A-Z)
                                negative_flag <= 1'b0; // Also clear flag
                            end
                            default: begin
                                // Skip any other characters
                                negative_flag <= 1'b0; // Clear flag
                            end
                        endcase
                        index <= index + 4'd1;
                    end else begin
                        // All elements processed
                        process_done <= 1'b1;
                        result <= accumulator;
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule