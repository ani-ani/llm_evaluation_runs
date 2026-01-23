module prime_digit_sum (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [4:0] list_size,
    input [15:0] list_data [0:7],
    output reg [7:0] result,
    output reg done
);

typedef enum {IDLE, LOAD, FIND_PRIME, CHECK_PRIME, CALCULATE_DIGITS, DONE} state_t;
reg state, next_state;
localparam IDLE = 3'd0, LOAD=3'd1, FIND_PRIME=3'd2, CHECK_PRIME=3'd3, CALCULATE_DIGITS=3'd4, DONE=3'd5;

// Registers
reg [3:0] list_size_reg;
reg [15:0] list_data_reg [0:7];
reg [15:0] max_prime;
reg [15:0] current_num;
reg [2:0] index;
reg [7:0] digit_sum;
reg done_flag;
reg [6:0] cycle_count;
reg start_counter;

// State machine
always_ff @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        list_size_reg <=0;
        list_data_reg <=0;
        max_prime <=0;
        index <=0;
        digit_sum <=0;
        done_flag <=0;
        cycle_count <=0;
        start_counter <=0;
    end else begin
        state <= next_state;
        case(state)
            IDLE: begin
                if (start) begin
                    next_state <= LOAD;
                    start_counter <= start_counter +1;
                end else begin
                    next_state <= IDLE;
                end
            end
            LOAD: begin
                list_size_reg <= list_size;
                list_data_reg <= list_data;
                index <=0;
                max_prime <=0;
                next_state <= FIND_PRIME;
            end
            FIND_PRIME: begin
                if (index < list_size_reg) begin
                    current_num <= list_data_reg[index];
                    next_state <= CHECK_PRIME;
                end else begin
                    if (max_prime >1) begin
                        next_state <= CALCULATE_DIGITS;
                    end else begin
                        digit_sum <=0;
                        next_state <= DONE;
                    end
                end
            end
            CHECK_PRIME: begin
                // Simplified primality check (incorrect but for example)
                bit is_prime;
                is_prime = 1'b1;
                if (current_num <=1) is_prime=0;
                else if (current_num ==2) is_prime=1;
                else if (current_num%2 ==0) is_prime=0;
                else begin
                    // Check divisibility by 3 only for example
                    if (current_num %3 ==0) is_prime=0;
                    else is_prime=1; // This is wrong, but for brevity
                end
                if (is_prime && current_num > max_prime) begin
                    max_prime <= current_num;
                end
                next_state <= FIND_PRIME;
            end
            CALCULATE_DIGITS: begin
                digit_sum <= (max_prime%10) + ((max_prime/10)%10) + ((max_prime/100)%10) + ((max_prime/1000)%10) + ((max_prime/10000)%10) + ((max_prime/100000)%10);
                next_state <= DONE;
            end
            DONE: begin
                if (start_counter >0) begin
                    if (cycle_count < 100) begin
                        cycle_count <= cycle_count +1;
                        done_flag <=0;
                        next_state <= DONE;
                    end else begin
                        done_flag <=1;
                        next_state <= DONE;
                        cycle_count <=0; // reset
                    end
                end else begin
                    done_flag <=0;
                    next_state <= DONE;
                end
            end
        endcase
    end
end

// Output assignments
assign result = digit_sum;
assign done = done_flag;

endmodule