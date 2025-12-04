module even_odd_counter (
    input reg clk,
    input reg rst_n,
    input reg start,
    input reg signed [15:0] num,
    output reg [3:0] even_count,
    output reg [3:0] odd_count,
    output reg done
);

    // State parameters
    localparam IDLE = 2'b00;
    localparam WORKING = 2'b01;
    localparam DONE = 2'b10;

    // Internal signals
    reg [1:0] state;
    reg [15:0] current_num;
    reg [2:0] digit_count;  // up to 5, so 3 bits
    reg start_r;  // to detect start pulse

    // Always block for state machine
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            even_count <= 4'b0;
            odd_count <= 4'b0;
            done <= 1'b0;
            current_num <= 16'b0;
            digit_count <= 3'b0;
            start_r <= 1'b0;
        end else begin
            // update start_r for edge detection
            start_r <= start;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && !start_r) begin  // rising edge of start
                        state <= WORKING;
                        even_count <= 4'b0;
                        odd_count <= 4'b0;
                        // take absolute value of num
                        if (num < 0) begin
                            current_num <= -num;
                        end else begin
                            current_num <= num;
                        end
                        digit_count <= 3'b0;
                    end
                end

                WORKING: begin
                    done <= 1'b0;
                    // process current digit (LSB)
                    if (current_num[0] == 1'b0) begin
                        even_count <= even_count + 1;
                    end else begin
                        odd_count <= odd_count + 1;
                    end

                    // update current_num and digit_count
                    current_num <= current_num >> 1;
                    digit_count <= digit_count + 1;

                    // check if done after this digit
                    if ((current_num >> 1) == 16'b0 || (digit_count + 1) == 3'd5) begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule