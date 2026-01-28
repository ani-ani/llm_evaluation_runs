module rearrange_to_divisible_by_7 (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] input_digits [0:15],
    input wire [3:0] input_length,
    output reg [3:0] output_digits [0:15],
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COUNT = 3'd1;
    localparam [2:0] DECREMENT = 3'd2;
    localparam [2:0] CALCULATE_MOD = 3'd3;
    localparam [2:0] LOOKUP = 3'd4;
    localparam [2:0] OUTPUT = 3'd5;

    reg [2:0] state, next_state;
    reg [4:0] count [0:9]; // counts for digits 0-9 (max 16)
    reg [2:0] mod_result;
    reg [3:0] digit_counter;
    reg [3:0] output_index;
    reg [15:0] current_perm;
    reg [2:0] mod_calc_count;
    reg [3:0] output_state;
    
    // Permutation table: for each possible modulo result (0-6), store 4-digit permutation
    reg [15:0] perm_table [0:6];
    initial begin
        perm_table[0] = 16'h1869; // 1869
        perm_table[1] = 16'h1896; // 1896
        perm_table[2] = 16'h1986; // 1986
        perm_table[3] = 16'h1698; // 1698
        perm_table[4] = 16'h6198; // 6198
        perm_table[5] = 16'h1689; // 1689
        perm_table[6] = 16'h1968; // 1968
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            digit_counter <= 4'd0;
            output_index <= 4'd0;
            mod_result <= 3'd0;
            current_perm <= 16'd0;
            mod_calc_count <= 3'd0;
            output_state <= 4'd0;
            // Reset counts
            for (integer i = 0; i < 10; i = i + 1) begin
                count[i] <= 5'd0;
            end
            // Reset output
            for (integer i = 0; i < 16; i = i + 1) begin
                output_digits[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Reset counters
                        for (integer i = 0; i < 10; i = i + 1) begin
                            count[i] <= 5'd0;
                        end
                        digit_counter <= 4'd0;
                        mod_result <= 3'd0;
                        current_perm <= 16'd0;
                        mod_calc_count <= 3'd0;
                        output_state <= 4'd0;
                    end
                end
                
                COUNT: begin
                    if (digit_counter < input_length) begin
                        count[input_digits[digit_counter]] <= count[input_digits[digit_counter]] + 5'd1;
                        digit_counter <= digit_counter + 4'd1;
                    end
                end
                
                DECREMENT: begin
                    if (count[1] > 0) count[1] <= count[1] - 5'd1;
                    if (count[6] > 0) count[6] <= count[6] - 5'd1;
                    if (count[8] > 0) count[8] <= count[8] - 5'd1;
                    if (count[9] > 0) count[9] <= count[9] - 5'd1;
                    digit_counter <= 4'd0;
                    mod_calc_count <= 3'd0;
                end
                
                CALCULATE_MOD: begin
                    if (mod_calc_count < 10) begin
                        if (count[mod_calc_count] > 0) begin
                            mod_result <= (mod_result * 3'd4 + mod_calc_count) % 3'd7;
                            count[mod_calc_count] <= count[mod_calc_count] - 5'd1;
                        end else begin
                            mod_calc_count <= mod_calc_count + 3'd1;
                        end
                    end
                end
                
                LOOKUP: begin
                    current_perm <= perm_table[mod_result];
                    output_index <= 4'd0;
                    output_state <= 4'd0;
                end
                
                OUTPUT: begin
                    if (output_index < input_length) begin
                        case (output_state)
                            4'd0: begin // Output non-zero digits except 1,6,8,9
                                if (digit_counter < 10) begin
                                    if (count[digit_counter] > 0 && digit_counter != 4'd0 && digit_counter != 4'd1 && digit_counter != 4'd6 && digit_counter != 4'd8 && digit_counter != 4'd9) begin
                                        output_digits[output_index] <= digit_counter;
                                        output_index <= output_index + 4'd1;
                                        count[digit_counter] <= count[digit_counter] - 5'd1;
                                    end else begin
                                        digit_counter <= digit_counter + 4'd1;
                                    end
                                end else begin
                                    output_state <= 4'd1;
                                    digit_counter <= 4'd0;
                                end
                            end
                            
                            4'd1: begin // Output permutation (1,6,8,9)
                                if (output_index <= input_length - 4'd4) begin
                                    output_digits[output_index] <= current_perm[15:12];
                                    output_digits[output_index + 4'd1] <= current_perm[11:8];
                                    output_digits[output_index + 4'd2] <= current_perm[7:4];
                                    output_digits[output_index + 4'd3] <= current_perm[3:0];
                                    output_index <= output_index + 4'd4;
                                end
                                output_state <= 4'd2;
                            end
                            
                            4'd2: begin // Output zeros
                                if (count[0] > 0) begin
                                    output_digits[output_index] <= 4'd0;
                                    output_index <= output_index + 4'd1;
                                    count[0] <= count[0] - 5'd1;
                                end else begin
                                    done <= 1'b1;
                                end
                            end
                        endcase
                    end else begin
                        done <= 1'b1;
                    end
                end
            endcase
        end
    end

    always @(*) begin
        case (state)
            IDLE: next_state = start ? COUNT : IDLE;
            COUNT: next_state = (digit_counter >= input_length) ? DECREMENT : COUNT;
            DECREMENT: next_state = CALCULATE_MOD;
            CALCULATE_MOD: begin
                if (mod_calc_count >= 10) next_state = LOOKUP;
                else if (count[mod_calc_count] > 0) next_state = CALCULATE_MOD;
                else next_state = CALCULATE_MOD; // Will increment counter
            end
            LOOKUP: next_state = OUTPUT;
            OUTPUT: begin
                if (done) next_state = IDLE;
                else next_state = OUTPUT;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule