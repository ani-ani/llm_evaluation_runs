module FilterFixedLengthStrings(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len_req,
    input wire [7:0] str_arr [0:15],
    output reg [7:0] result_arr [0:15],
    output reg [3:0] result_count,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] CALC_LEN  = 2'd1;
    localparam [1:0] STORE     = 2'd2;
    localparam [1:0] FINISH    = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] current_index;
    reg [3:0] current_len;
    reg [7:0] i;
    reg match_found;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            current_index <= 4'd0;
            current_len <= 4'd0;
            i <= 8'd0;
            match_found <= 1'b0;
            result_count <= 4'd0;
            done <= 1'b0;

            // Initialize result_arr to all zeros
            integer j;
            for (j = 0; j < 16; j = j + 1) begin
                result_arr[j] <= 8'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_index <= 4'd0;
                        result_count <= 4'd0;
                        next_state <= CALC_LEN;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CALC_LEN: begin
                    // Calculate length of current string
                    current_len <= 4'd0;
                    i <= 8'd0;
                    match_found <= 1'b0;

                    // Scan for null byte or end of string
                    for (i = 0; i < 8; i = i + 1) begin
                        if (str_arr[current_index][i] == 8'd0) begin
                            current_len <= i;
                            match_found <= 1'b1;
                            break;
                        end
                    end

                    // If no null byte found, length is 8
                    if (!match_found) begin
                        current_len <= 4'd8;
                    end

                    next_state <= STORE;
                end

                STORE: begin
                    // Check if length matches len_req
                    if (current_len == len_req) begin
                        // Copy string to result_arr
                        integer k;
                        for (k = 0; k < 8; k = k + 1) begin
                            result_arr[current_index][k] <= str_arr[current_index][k];
                        end
                        result_count <= result_count + 4'd1;
                    end else begin
                        // Zero out the result slot
                        integer k;
                        for (k = 0; k < 8; k = k + 1) begin
                            result_arr[current_index][k] <= 8'd0;
                        end
                    end

                    // Move to next index or finish
                    if (current_index == 4'd15) begin
                        next_state <= FINISH;
                    end else begin
                        current_index <= current_index + 4'd1;
                        next_state <= CALC_LEN;
                    end
                end

                FINISH: begin
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