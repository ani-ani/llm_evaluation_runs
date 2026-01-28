module correct_bracketing(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input valid_in,
    input done_in,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK_CHAR = 2'd1;
    localparam [1:0] VERIFY_FINAL = 2'd2;
    localparam [1:0] DONE = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [4:0] counter;          // 5-bit counter (supports up to 31)
    reg [3:0] char_count;       // Track max 16 characters
    reg error_flag;
    reg [7:0] stored_char;      // Store character for processing
    localparam [4:0] COUNTER_WIDTH = 5'd31;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            counter <= 5'd0;
            char_count <= 4'd0;
            error_flag <= 1'b0;
            stored_char <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 5'd0;
                    char_count <= 4'd0;
                    error_flag <= 1'b0;
                    if (start) begin
                        state <= CHECK_CHAR;
                    end
                end

                CHECK_CHAR: begin
                    if (valid_in) begin
                        // Process character
                        stored_char <= char_in;
                        if (char_in == 8'h28) begin // '(' character
                            if (counter < 5'd31) begin
                                counter <= counter + 5'd1;
                            end else begin
                                error_flag <= 1'b1;
                            end
                            if (char_count < 4'd15) begin
                                char_count <= char_count + 4'd1;
                            end
                        end else if (char_in == 8'h29) begin // ')' character
                            if (counter > 5'd0) begin
                                counter <= counter - 5'd1;
                            end else begin
                                error_flag <= 1'b1; // Too many closing brackets
                            end
                            if (char_count < 4'd15) begin
                                char_count <= char_count + 4'd1;
                            end
                        end
                        // Non-parenthesis characters are ignored
                        state <= CHECK_CHAR;
                    end else if (done_in) begin
                        // End of string, move to verification
                        state <= VERIFY_FINAL;
                    end
                end

                VERIFY_FINAL: begin
                    // Check final conditions
                    if (error_flag || (counter != 5'd0)) begin
                        result <= 1'b0;
                    end else begin
                        result <= 1'b1;
                    end
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule