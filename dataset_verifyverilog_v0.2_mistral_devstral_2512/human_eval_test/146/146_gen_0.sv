module special_filter (
    input clk,
    input rst_n,
    input start,
    input [2:0] array_len,
    input [15:0] nums [0:7],
    output reg [3:0] result,
    output reg done
);

    // States
    typedef enum logic [1:0] {
        IDLE,
        PROCESSING,
        DONE
    } state_t;

    state_t state;
    reg [2:0] index;
    reg [3:0] count;
    reg [15:0] abs_num;
    reg [3:0] first_digit;
    reg [3:0] last_digit;
    reg [3:0] temp;
    reg [3:0] div_counter;
    reg [3:0] mod_counter;
    reg [3:0] digit_counter;
    reg [15:0] temp_num;
    reg [3:0] i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 0;
            count <= 0;
            result <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PROCESSING;
                        index <= 0;
                        count <= 0;
                        result <= 0;
                        done <= 0;
                    end
                end
                PROCESSING: begin
                    if (index == array_len) begin
                        state <= DONE;
                        result <= count;
                        done <= 1;
                    end else begin
                        // Get absolute value
                        abs_num <= nums[index][15] ? ~nums[index] + 1 : nums[index];
                        
                        // Check if abs > 10
                        if (abs_num > 10) begin
                            // Extract last digit (abs_num % 10)
                            temp_num <= abs_num;
                            mod_counter <= 0;
                            while (mod_counter < 10) begin
                                if (temp_num >= 10) begin
                                    temp_num <= temp_num - 10;
                                end
                                mod_counter <= mod_counter + 1;
                            end
                            last_digit <= temp_num;
                            
                            // Extract first digit
                            temp_num <= abs_num;
                            digit_counter <= 0;
                            while (temp_num >= 10) begin
                                temp_num <= temp_num - 10;
                                digit_counter <= digit_counter + 1;
                            end
                            first_digit <= temp_num;
                            
                            // Check if both digits are odd
                            if ((first_digit % 2 != 0) && (last_digit % 2 != 0)) begin
                                count <= count + 1;
                            end
                        end
                        index <= index + 1;
                    end
                end
                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule