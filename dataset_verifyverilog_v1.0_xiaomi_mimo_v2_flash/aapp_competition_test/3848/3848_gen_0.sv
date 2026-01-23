module next_tolerable_string(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] p,
    input [7:0] s [0:7],
    output reg [7:0] result [0:7],
    output reg done,
    output reg exists
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] PROCESS   = 3'd2;
    localparam [2:0] CHECK     = 3'd3;
    localparam [2:0] FILL      = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    reg [2:0] state, next_state;
    reg [3:0] pos;
    reg [7:0] temp_result [0:7];
    reg [7:0] char;
    reg palindrome_found;
    reg increment_done;
    reg [7:0] base_char;
    reg [7:0] max_char;
    reg [7:0] current_char;
    integer i;
    reg [7:0] start_char;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            exists <= 1'b0;
            pos <= 4'd0;
            char <= 8'd0;
            palindrome_found <= 1'b0;
            increment_done <= 1'b0;
            base_char <= 8'd0;
            max_char <= 8'd0;
            current_char <= 8'd0;
            start_char <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                result[i] <= 8'd0;
                temp_result[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    exists <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                    end else begin
                        state <= IDLE;
                    end
                end

                LOAD: begin
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < n) begin
                            temp_result[i] <= s[i];
                        end else begin
                            temp_result[i] <= 8'd0;
                        end
                    end
                    pos <= n - 4'd1;
                    state <= PROCESS;
                end

                PROCESS: begin
                    if (pos >= n) begin
                        // Processed all positions, no solution
                        exists <= 1'b0;
                        state <= FINISH;
                    end else begin
                        // Try to increment character at position pos
                        char <= temp_result[pos] + 8'd1;
                        current_char <= temp_result[pos] + 8'd1;
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    palindrome_found <= 1'b0;
                    // Check if current_char is valid (less than max)
                    if (current_char < start_char) begin
                        // Still within valid range
                        if (pos >= 2) begin
                            if (current_char == temp_result[pos-1] || current_char == temp_result[pos-2]) begin
                                // Palindrome found, try next char
                                current_char <= current_char + 8'd1;
                                state <= CHECK;
                            end else begin
                                // No palindrome, update temp_result and fill rest
                                temp_result[pos] <= current_char;
                                for (i = pos + 1; i < 8; i = i + 1) begin
                                    temp_result[i] <= 8'd0;
                                end
                                pos <= pos + 4'd1;
                                state <= FILL;
                            end
                        end else if (pos == 1) begin
                            if (current_char == temp_result[0]) begin
                                current_char <= current_char + 8'd1;
                                state <= CHECK;
                            end else begin
                                temp_result[pos] <= current_char;
                                for (i = pos + 1; i < 8; i = i + 1) begin
                                    temp_result[i] <= 8'd0;
                                end
                                pos <= pos + 4'd1;
                                state <= FILL;
                            end
                        end else begin // pos == 0
                            temp_result[pos] <= current_char;
                            for (i = pos + 1; i < 8; i = i + 1) begin
                                temp_result[i] <= 8'd0;
                            end
                            pos <= pos + 4'd1;
                            state <= FILL;
                        end
                    end else begin
                        // Exceeded range, move to previous position
                        pos <= pos - 4'd1;
                        state <= PROCESS;
                    end
                end

                FILL: begin
                    if (pos >= n) begin
                        exists <= 1'b1;
                        state <= FINISH;
                    end else begin
                        // Fill current position with smallest valid char
                        base_char <= 8'h61; // 'a'
                        current_char <= 8'h61;
                        state <= CHECK;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    for (i = 0; i < 8; i = i + 1) begin
                        result[i] <= temp_result[i];
                    end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule