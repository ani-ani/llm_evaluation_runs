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
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] CHECK = 3'd3;
    localparam [2:0] FILL = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] current [0:7];
    reg [7:0] temp [0:7];
    reg [3:0] pos;
    reg [3:0] i, j;
    reg found;
    reg [7:0] char;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd64;

    // Helper function to check if character is valid
    function automatic reg is_valid_char;
        input [7:0] c;
        input [3:0] p_val;
        begin
            is_valid_char = (c >= 8'd97) && (c < (8'd97 + p_val));
        end
    endfunction

    // Helper function to check for palindromes
    function automatic reg has_palindrome;
        input [7:0] str [0:7];
        input [3:0] len;
        reg [3:0] k, l;
        begin
            has_palindrome = 1'b0;
            for (k = 0; k < len - 1; k = k + 1) begin
                if (str[k] == str[k + 1]) begin
                    has_palindrome = 1'b1;
                    return has_palindrome;
                end
                if (k < len - 2 && str[k] == str[k + 2]) begin
                    has_palindrome = 1'b1;
                    return has_palindrome;
                end
            end
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            exists <= 1'b0;
            pos <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            found <= 1'b0;
            char <= 8'd0;
            cycle_count <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
                current[i] <= 8'd0;
                temp[i] <= 8'd0;
                result[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            done <= 1'b0;
            exists <= 1'b0;
            cycle_count <= cycle_count + 4'd1;

            case (state)
                IDLE: begin
                    if (start) begin
                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < n) begin
                            current[i] <= s[i];
                        end else begin
                            current[i] <= 8'd0;
                        end
                    end
                    next_state <= PROCESS;
                end

                PROCESS: begin
                    pos <= n - 4'd1;
                    found <= 1'b0;
                    while (!found && pos >= 0) begin
                        char <= current[pos] + 8'd1;
                        if (is_valid_char(char, p)) begin
                            temp[pos] <= char;
                            for (i = 0; i < pos; i = i + 1) begin
                                temp[i] <= current[i];
                            end
                            found <= 1'b1;
                        end else begin
                            pos <= pos - 4'd1;
                        end
                    end

                    if (found) begin
                        next_state <= CHECK;
                    end else begin
                        exists <= 1'b0;
                        next_state <= FINISH;
                    end
                end

                CHECK: begin
                    for (i = pos + 4'd1; i < n; i = i + 1) begin
                        temp[i] <= 8'd97;
                    end

                    if (!has_palindrome(temp, n)) begin
                        next_state <= FILL;
                    end else begin
                        pos <= pos - 4'd1;
                        if (pos >= 0) begin
                            next_state <= PROCESS;
                        end else begin
                            exists <= 1'b0;
                            next_state <= FINISH;
                        end
                    end
                end

                FILL: begin
                    for (i = 0; i < n; i = i + 1) begin
                        result[i] <= temp[i];
                    end
                    exists <= 1'b1;
                    next_state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    exists <= exists;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Cycle counter safety
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 4'd0;
        end else if (cycle_count >= MAX_CYCLES) begin
            cycle_count <= 4'd0;
            next_state <= IDLE;
        end
    end

endmodule