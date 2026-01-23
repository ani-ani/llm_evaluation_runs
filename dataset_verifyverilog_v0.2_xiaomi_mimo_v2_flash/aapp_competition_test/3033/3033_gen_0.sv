module min_number_finder(
    input clk,
    input rst_n,
    input start,
    input [7:0] N,
    output reg [63:0] result,
    output reg done,
    output reg impossible
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam FACTORING = 2'b01;
    localparam SORTING = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] state;

    // Algorithm registers
    reg [7:0] current_N;
    reg [3:0] digit_buffer [0:15];
    reg [4:0] digit_count;
    reg [3:0] divisor;
    reg [4:0] cycle_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            impossible <= 1'b0;
            result <= 64'b0;
            digit_count <= 5'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= FACTORING;
                        current_N <= N;
                        digit_count <= 5'b0;
                        divisor <= 4'd9;
                        cycle_counter <= 5'd0;
                    end
                end

                FACTORING: begin
                    // Greedy factorization: 9..2
                    // Fixed steps to ensure 16 cycle budget
                    if (cycle_counter < 14 && divisor >= 4'd2) begin
                        if (current_N % divisor == 0) begin
                            current_N <= current_N / divisor;
                            digit_buffer[digit_count] <= divisor;
                            digit_count <= digit_count + 1;
                            // Remain on same divisor to try again
                        end else begin
                            divisor <= divisor - 1;
                        end
                        cycle_counter <= cycle_counter + 1;
                    end else begin
                        state <= SORTING;
                    end
                end

                SORTING: begin
                    // Check impossibility
                    if (current_N > 8'd1 || (digit_count == 0 && N != 1)) begin
                        state <= DONE;
                        impossible <= 1'b1;
                        result <= 64'b0;
                    end else begin
                        state <= DONE;
                        impossible <= 1'b0;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    // Construct result
                    if (N == 1) begin
                        result <= 64'd1;
                    end else if (!impossible) begin
                        // Unrolled construction: read buffer in reverse (ascending order)
                        // Buffer holds digits collected 9..2 (e.g. 8, 3 for N=24)
                        // To minimize X, we need 3, 8. So read from end.
                        result <= 64'b0; // Default
                        begin : construct_loop
                            integer i;
                            reg [63:0] temp_res;
                            temp_res = 64'b0;
                            for (i = 0; i < 16; i = i + 1) begin
                                if (i < digit_count) begin
                                    temp_res = temp_res * 10 + digit_buffer[digit_count - 1 - i];
                                end
                            end
                            result <= temp_res;
                        end
                    end
                end
            endcase
        end
    end
endmodule