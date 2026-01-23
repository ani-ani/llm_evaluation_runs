module dessert_finder (
    input clk,
    input rst_n,
    input start,
    input [8:0] P,
    output reg valid,
    output reg [8:0] B_out,
    output reg [8:0] M_out,
    output reg done,
    output reg [6:0] count
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        COMPUTE,
        OUTPUT,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal signals
    reg [8:0] B;
    reg [8:0] M;
    reg [8:0] B_temp;
    reg [8:0] M_temp;
    reg [8:0] B_fifo [0:63];
    reg [8:0] M_fifo [0:63];
    reg [5:0] fifo_wr_ptr;
    reg [5:0] fifo_rd_ptr;
    reg [5:0] fifo_count;
    reg [8:0] B_iter;
    reg [8:0] M_iter;
    reg [9:0] digit_mask;
    reg [9:0] temp_mask;
    reg [9:0] P_digits;
    reg [9:0] B_digits;
    reg [9:0] M_digits;
    reg digit_valid;
    reg [9:0] counter;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            B <= 0;
            M <= 0;
            B_temp <= 0;
            M_temp <= 0;
            fifo_wr_ptr <= 0;
            fifo_rd_ptr <= 0;
            fifo_count <= 0;
            B_iter <= 0;
            M_iter <= 0;
            digit_mask <= 0;
            temp_mask <= 0;
            P_digits <= 0;
            B_digits <= 0;
            M_digits <= 0;
            digit_valid <= 0;
            counter <= 0;
            valid <= 0;
            B_out <= 0;
            M_out <= 0;
            done <= 0;
            count <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                end
            end
            COMPUTE: begin
                if (counter == 1000) begin
                    if (fifo_count > 0) begin
                        next_state = OUTPUT;
                    end else begin
                        next_state = DONE;
                    end
                end
            end
            OUTPUT: begin
                if (fifo_rd_ptr == fifo_wr_ptr) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // Compute logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 0;
            B_iter <= 0;
            M_iter <= 0;
            digit_mask <= 0;
            temp_mask <= 0;
            P_digits <= 0;
            B_digits <= 0;
            M_digits <= 0;
            digit_valid <= 0;
        end else if (current_state == COMPUTE) begin
            if (counter < 1000) begin
                counter <= counter + 1;
                B_iter <= counter;
                M_iter <= P - B_iter;

                // Check B < M
                if (B_iter < M_iter) begin
                    // Extract digits from P, B, M
                    P_digits <= extract_digits(P);
                    B_digits <= extract_digits(B_iter);
                    M_digits <= extract_digits(M_iter);

                    // Check for distinct digits
                    digit_mask <= P_digits | B_digits | M_digits;
                    temp_mask <= P_digits & B_digits;
                    temp_mask <= temp_mask | (P_digits & M_digits);
                    temp_mask <= temp_mask | (B_digits & M_digits);

                    digit_valid <= (temp_mask == 0);

                    // Store valid pair in FIFO
                    if (digit_valid && fifo_count < 64) begin
                        B_fifo[fifo_wr_ptr] <= B_iter;
                        M_fifo[fifo_wr_ptr] <= M_iter;
                        fifo_wr_ptr <= fifo_wr_ptr + 1;
                        fifo_count <= fifo_count + 1;
                    end
                end
            end
        end
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid <= 0;
            B_out <= 0;
            M_out <= 0;
            done <= 0;
            count <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    valid <= 0;
                    done <= 0;
                    count <= 0;
                end
                COMPUTE: begin
                    valid <= 0;
                    done <= 0;
                    count <= fifo_count;
                end
                OUTPUT: begin
                    if (fifo_rd_ptr < fifo_wr_ptr) begin
                        valid <= 1;
                        B_out <= B_fifo[fifo_rd_ptr];
                        M_out <= M_fifo[fifo_rd_ptr];
                        fifo_rd_ptr <= fifo_rd_ptr + 1;
                    end else begin
                        valid <= 0;
                    end
                    done <= 0;
                    count <= fifo_count;
                end
                DONE: begin
                    valid <= 0;
                    done <= 1;
                    count <= fifo_count;
                end
                default: begin
                    valid <= 0;
                    done <= 0;
                    count <= 0;
                end
            endcase
        end
    end

    // Digit extraction function
    function [9:0] extract_digits(input [8:0] num);
        reg [9:0] digits;
        begin
            digits = 0;
            if (num >= 100) begin
                digits[num / 100] = 1;
                digits[(num / 10) % 10] = 1;
                digits[num % 10] = 1;
            end else if (num >= 10) begin
                digits[num / 10] = 1;
                digits[num % 10] = 1;
            end else begin
                digits[num] = 1;
            end
            return digits;
        end
    endfunction

endmodule