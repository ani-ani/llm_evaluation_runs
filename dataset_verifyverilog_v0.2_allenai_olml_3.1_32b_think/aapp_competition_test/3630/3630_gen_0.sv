module string_puzzle_solver (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [7:0][7:0] s1,
    input [7:0][7:0] s2,
    output reg [15:0] result,
    output reg done
);

// Internal registers
reg [1:0] state, next_state;
reg [15:0] sum_temp;
reg [15:0] result_reg;
reg done_reg;

// State definitions
parameter IDLE = 2'b00;
parameter COMPUTE = 2'b01;
parameter DONE = 2'b10;

// Combinatorial function to compute the sum
function automatic [15:0] compute_sum(input [7:0][7:0] s1, input [7:0][7:0] s2);
    reg [15:0] sum_total =0;
    
    // Character 0
    reg [7:0] s1_0 = s1[0][7:0];
    reg [7:0] s2_0 = s2[0][7:0];
    reg [7:0] diff_unsigned_0 = s2_0 - s1_0;
    reg [15:0] temp_diff_0;
    if (diff_unsigned_0 >= 8'd128) temp_diff_0 = diff_unsigned_0 - 256;
    else temp_diff_0 = diff_unsigned_0;
    reg [4:0] temp_diff_mod_0;
    temp_diff_mod_0 = temp_diff_0 % 26;
    if (temp_diff_mod_0 < 0) temp_diff_mod_0 += 26;
    if (temp_diff_mod_0 > 13) temp_diff_mod_0 -= 26;
    reg [4:0] temp_abs_0;
    if (temp_diff_mod_0 >=0) temp_abs_0 = temp_diff_mod_0;
    else temp_abs_0 = -temp_diff_mod_0;
    sum_total = temp_abs_0;
    
    // Character 1
    reg [7:0] s1_1 = s1[1][7:0];
    reg [7:0] s2_1 = s2[1][7:0];
    reg [7:0] diff_unsigned_1 = s2_1 - s1_1;
    reg [15:0] temp_diff_1;
    if (diff_unsigned_1 >=8'd128) temp_diff_1 = diff_unsigned_1 -256;
    else temp_diff_1 = diff_unsigned_1;
    reg [4:0] temp_diff_mod_1;
    temp_diff_mod_1 = temp_diff_1 %26;
    if (temp_diff_mod_1 <0) temp_diff_mod_1 +=26;
    if (temp_diff_mod_1 >13) temp_diff_mod_1 -=26;
    reg [4:0] temp_abs_1;
    if (temp_diff_mod_1 >=0) temp_abs_1 = temp_diff_mod_1;
    else temp_abs_1 = -temp_diff_mod_1;
    sum_total += temp_abs_1;
    
    // Character 2
    reg [7:0] s1_2 = s1[2][7:0];
    reg [7:0] s2_2 = s2[2][7:0];
    reg [7:0] diff_unsigned_2 = s2_2 - s1_2;
    reg [15:0] temp_diff_2;
    if (diff_unsigned_2 >=8'd128) temp_diff_2 = diff_unsigned_2 -256;
    else temp_diff_2 = diff_unsigned_2;
    reg [4:0] temp_diff_mod_2;
    temp_diff_mod_2 = temp_diff_2 %26;
    if (temp_diff_mod_2 <0) temp_diff_mod_2 +=26;
    if (temp_diff_mod_2 >13) temp_diff_mod_2 -=26;
    reg [4:0] temp_abs_2;
    if (temp_diff_mod_2 >=0) temp_abs_2 = temp_diff_mod_2;
    else temp_abs_2 = -temp_diff_mod_2;
    sum_total += temp_abs_2;
    
    // Character 3
    reg [7:0] s1_3 = s1[3][7:0];
    reg [7:0] s2_3 = s2[3][7:0];
    reg [7:0] diff_unsigned_3 = s2_3 - s1_3;
    reg [15:0] temp_diff_3;
    if (diff_unsigned_3 >=8'd128) temp_diff_3 = diff_unsigned_3 -256;
    else temp_diff_3 = diff_unsigned_3;
    reg [4:0] temp_diff_mod_3;
    temp_diff_mod_3 = temp_diff_3 %26;
    if (temp_diff_mod_3 <0) temp_diff_mod_3 +=26;
    if (temp_diff_mod_3 >13) temp_diff_mod_3 -=26;
    reg [4:0] temp_abs_3;
    if (temp_diff_mod_3 >=0) temp_abs_3 = temp_diff_mod_3;
    else temp_abs_3 = -temp_diff_mod_3;
    sum_total += temp_abs_3;
    
    // Character 4
    reg [7:0] s1_4 = s1[4][7:0];
    reg [7:0] s2_4 = s2[4][7:0];
    reg [7:0] diff_unsigned_4 = s2_4 - s1_4;
    reg [15:0] temp_diff_4;
    if (diff_unsigned_4 >=8'd128) temp_diff_4 = diff_unsigned_4 -256;
    else temp_diff_4 = diff_unsigned_4;
    reg [4:0] temp_diff_mod_4;
    temp_diff_mod_4 = temp_diff_4 %26;
    if (temp_diff_mod_4 <0) temp_diff_mod_4 +=26;
    if (temp_diff_mod_4 >13) temp_diff_mod_4 -=26;
    reg [4:0] temp_abs_4;
    if (temp_diff_mod_4 >=0) temp_abs_4 = temp_diff_mod_4;
    else temp_abs_4 = -temp_diff_mod_4;
    sum_total += temp_abs_4;
    
    // Character 5
    reg [7:0] s1_5 = s1[5][7:0];
    reg [7:0] s2_5 = s2[5][7:0];
    reg [7:0] diff_unsigned_5 = s2_5 - s1_5;
    reg [15:0] temp_diff_5;
    if (diff_unsigned_5 >=8'd128) temp_diff_5 = diff_unsigned_5 -256;
    else temp_diff_5 = diff_unsigned_5;
    reg [4:0] temp_diff_mod_5;
    temp_diff_mod_5 = temp_diff_5 %26;
    if (temp_diff_mod_5 <0) temp_diff_mod_5 +=26;
    if (temp_diff_mod_5 >13) temp_diff_mod_5 -=26;
    reg [4:0] temp_abs_5;
    if (temp_diff_mod_5 >=0) temp_abs_5 = temp_diff_mod_5;
    else temp_abs_5 = -temp_diff_mod_5;
    sum_total += temp_abs_5;
    
    // Character 6
    reg [7:0] s1_6 = s1[6][7:0];
    reg [7:0] s2_6 = s2[6][7:0];
    reg [7:0] diff_unsigned_6 = s2_6 - s1_6;
    reg [15:0] temp_diff_6;
    if (diff_unsigned_6 >=8'd128) temp_diff_6 = diff_unsigned_6 -256;
    else temp_diff_6 = diff_unsigned_6;
    reg [4:0] temp_diff_mod_6;
    temp_diff_mod_6 = temp_diff_6 %26;
    if (temp_diff_mod_6 <0) temp_diff_mod_6 +=26;
    if (temp_diff_mod_6 >13) temp_diff_mod_6 -=26;
    reg [4:0] temp_abs_6;
    if (temp_diff_mod_6 >=0) temp_abs_6 = temp_diff_mod_6;
    else temp_abs_6 = -temp_diff_mod_6;
    sum_total += temp_abs_6;
    
    // Character 7
    reg [7:0] s1_7 = s1[7][7:0];
    reg [7:0] s2_7 = s2[7][7:0];
    reg [7:0] diff_unsigned_7 = s2_7 - s1_7;
    reg [15:0] temp_diff_7;
    if (diff_unsigned_7 >=8'd128) temp_diff_7 = diff_unsigned_7 -256;
    else temp_diff_7 = diff_unsigned_7;
    reg [4:0] temp_diff_mod_7;
    temp_diff_mod_7 = temp_diff_7 %26;
    if (temp_diff_mod_7 <0) temp_diff_mod_7 +=26;
    if (temp_diff_mod_7 >13) temp_diff_mod_7 -=26;
    reg [4:0] temp_abs_7;
    if (temp_diff_mod_7 >=0) temp_abs_7 = temp_diff_mod_7;
    else temp_abs_7 = -temp_diff_mod_7;
    sum_total += temp_abs_7;
    
    return sum_total;
endfunction

// State machine logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        next_state <= IDLE;
        sum_temp <= 0;
        result_reg <=0;
        done_reg <=0;
    end else begin
        state <= next_state;
        
        // Default next state
        next_state = state;
        
        if (state == IDLE) begin
            if (start) begin
                next_state = COMPUTE;
                sum_temp <= compute_sum(s1, s2);
            end
        end else if (state == COMPUTE) begin
            next_state = DONE;
            result_reg <= sum_temp;
            done_reg <=1;
        end else if (state == DONE) begin
            // Stay in DONE
        end
    end
end

// Assign outputs
assign done = done_reg;
assign result = result_reg;

endmodule