module HouseNumberCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] L,
    input wire [63:0] R,
    output reg [31:0] count,
    output reg done
);
    localparam [4:0] IDLE = 5'd0;
    localparam [4:0] INIT_DP_R = 5'd1;
    localparam [4:0] PROCESS_R = 5'd2;
    localparam [4:0] STORE_R = 5'd3;
    localparam [4:0] INIT_DP_L = 5'd4;
    localparam [4:0] PROCESS_L = 5'd5;
    localparam [4:0] STORE_L = 5'd6;
    localparam [4:0] SUBTRACT = 5'd7;
    localparam [4:0] FINISH = 5'd8;
    
    localparam [29:0] MOD_VALUE = 30'd1000000007;
    
    reg [4:0] state, next_state;
    
    reg [3:0] num_digits [0:15];
    reg [3:0] processing_digits [0:15];
    
    reg [4:0] position;
    reg [1:0] curr_tight;
    reg [5:0] curr_diff;
    reg [3:0] curr_digit;
    reg loop_done;
    
    reg [29:0] current_dp [0:1][0:1][0:32];
    reg [29:0] next_dp [0:1][0:1][0:32];
    
    reg [29:0] result_f_R;
    reg [29:0] result_f_L;
    reg [29:0] sub_result;
    
    integer i, j, k, m, n;
    
    wire [63:0] L_minus_1;
    
    assign L_minus_1 = decrement_bcd(L);
    
    function [63:0] decrement_bcd(input [63:0] val);
        reg borrow;
        integer idx;
        begin
            decrement_bcd = val;
            borrow = 1'b1;
            for (idx =0; idx <16; idx = idx +1) begin
                if (borrow) begin
                    if (decrement_bcd[4*idx +:4] == 4'd0) begin
                        decrement_bcd[4*idx +:4] = 4'd9;
                        borrow = 1'b1;
                    end else begin
                        decrement_bcd[4*idx +:4] = decrement_bcd[4*idx +:4] - 1'b1;
                        borrow = 1'b0;
                    end
                end
            end
        end
    endfunction
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 30'd0;
            done <= 1'b0;
            
            for (i=0; i<2; i=i+1) begin
                for (j=0; j<2; j=j+1) begin
                    for (k=0; k<33; k=k+1) begin
                        current_dp[i][j][k] <= 30'd0;
                        next_dp[i][j][k] <= 30'd0;
                    end
                end
            end
            
            position <= 5'd0;
            curr_tight <= 2'd0;
            curr_diff <= 6'd0;
            curr_digit <= 4'd0;
            loop_done <= 1'b0;
            result_f_R <= 30'd0;
            result_f_L <= 30'd0;
            sub_result <= 30'd0;
            
            for (m=0; m<16; m=m+1) begin
                num_digits[m] <= 4'd0;
                processing_digits[m] <= 4'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    count <= 30'd0;
                    if (start) begin
                        for (m=0; m<16; m=m+1) begin
                            num_digits[m] <= R[4*m +:4];
                        end
                        next_state <= INIT_DP_R;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                INIT_DP_R: begin
                    position <= 5'd0;
                    loop_done <= 1'b0;
                    for (i=0; i<2; i=i+1) begin
                        for (j=0; j<2; j=j+1) begin
                            for (k=0; k<33; k=k+1) begin
                                current_dp[i][j][k] <= 30'd0;
                            end
                        end
                    end
                    current_dp[1][0][16] <= 30'd1;
                    next_state <= PROCESS_R;
                    curr_tight <= 2'd0;
                    curr_diff <= 6'd0;
                    curr_digit <= 4'd0;
                    for (i=0; i<2; i=i+1) begin
                        for (j=0; j<2; j=j+1) begin
                            for (k=0; k<33; k=k+1) begin
                                next_dp[i][j][k] <= 30'd0;
                            end
                        end
                    end
                end
                
                PROCESS_R: begin
                    if (!loop_done) begin
                        if (curr_digit === 4) begin
                            curr_digit <= 4'd5;
                        end else if (curr_digit <= 4'd9) begin
                            if (current_dp[curr_tight[0]][loop_done ? 1'bx : curr_tight[0] ? j[0] : j[0]][curr_diff] !== 30'd0) begin
                                if (!((curr_tight[0] === 1'b1) && (curr_digit > processing_digits[position]))) begin
                                    reg new_tight = (curr_tight[0] === 1'b1) && (curr_digit == processing_digits[position]);
                                    reg new_nonzero = |curr_tight[0] | (curr_digit != 4'd0);
                                    reg [6:0] new_diff;
                                    
                                    new_diff = curr_diff;
                                    if (curr_digit == 4'd6 || curr_digit == 4'd8) begin
                                        new_diff = curr_diff + 6'd1;
                                    end else begin
                                        new_diff = curr_diff - 6'd1;
                                    end
                                    
                                    if (new_diff >= 6'd0 && new_diff <= 6'd32) begin
                                        reg [29:0] temp_sum;
                                        temp_sum = next_dp[new_tight][new_nonzero][new_diff] + current_dp[curr_tight[0]][curr_diff];
                                        if (temp_sum >= MOD_VALUE) temp_sum = temp_sum - MOD_VALUE;
                                        next_dp[new_tight][new_nonzero][new_diff] <= temp_sum;
                                    end
                                end
                            end
                            
                            if (curr_digit == 4'd9) begin
                                curr_digit <= 4'd0;
                                if (curr_diff == 6'd32) begin
                                    curr_diff <= 6'd0;
                                    curr_tight <= curr_tight + 1'b1;
                                end else begin
                                    curr_diff <= curr_diff + 1'b1;
                                end
                            end else begin
                                curr_digit <= curr_digit + 1'b1;
                            end
                        end
                        
                        if (curr_tight == 2'd2) begin
                            loop_done <= 1'b1;
                        end
                    end else begin
                        for (i=0; i<2; i=i+1) begin
                            for (j=0; j<2; j=j+1) begin
                                for (k=0; k<33; k=k+1) begin
                                    current_dp[i][j][k] <= next_dp[i][j][k];
                                    next_dp[i][j][k] <= 30'd0;
                                end
                            end
                        end
                        
                        if (position == 5'd15) begin
                            result_f_R <= (current_dp[0][1][16] + current_dp[1][1][16]) % MOD_VALUE;
                            next_state <= STORE_R;
                        end else begin
                            position <= position + 1'b1;
                            curr_tight <= 2'd0;
                            curr_diff <= 6'd0;
                            curr_digit <= 4'd0;
                            loop_done <= 1'b0;
                        end
                    end
                end
                
                STORE_R: begin
                    for (m=0; m<16; m=m+1) begin
                        processing_digits[m] <= L_minus_1[4*m +:4];
                    end
                    next_state <= INIT_DP_L;
                end
                
                INIT_DP_L: begin
                    for (i=0; i<2; i=i+1) begin
                        for (j=0; j<2; j=j+1) begin
                            for (k=0; k<33; k=k+1) begin
                                current_dp[i][j][k] <= 30'd0;
                            end
                        end
                    end
                    current_dp[1][0][16] <= 30'd1;
                    position <= 5'd0;
                    loop_done <= 1'b0;
                    curr_tight <= 2'd0;
                    curr_diff <= 6'd0;
                    curr_digit <= 4'd0;
                    for (i=0; i<2; i=i+1) begin
                        for (j=0; j<2; j=j+1) begin
                            for (k=0; k<33; k=k+1) begin
                                next_dp[i][j][k] <= 30'd0;
                            end
                        end
                    end
                    next_state <= PROCESS_L;
                end
                
                PROCESS_L: begin
                    if (!loop_done) begin
                        if (curr_digit ===4) begin
                            curr_digit <=4'd5;
                        end else if (curr_digit <=4'd9) begin
                            if (current_dp[curr_tight[0]][curr_diff] !==30'd0) begin
                                if (!((curr_tight[0]===1'b1) && (curr_digit > processing_digits[position]))) begin
                                    reg new_tight = (curr_tight[0]===1'b1) && (curr_digit == processing_digits[position]);
                                    reg new_nonzero = |curr_tight[0] | (curr_digit !=4'd0);
                                    reg [6:0] new_diff;
                                    
                                    new_diff = curr_diff;
                                    if (curr_digit ==4'd6 || curr_digit ==4'd8) begin
                                        new_diff = curr_diff +6'd1;
                                    end else begin
                                        new_diff = curr_diff -6'd1;
                                    end
                                    
                                    if (new_diff >=6'd0 && new_diff <=6'd32) begin
                                        reg [29:0] temp_sum;
                                        temp_sum = next_dp[new_tight][new_nonzero][new_diff] + current_dp[curr_tight[0]][curr_diff];
                                        if (temp_sum >= MOD_VALUE) temp_sum = temp_sum - MOD_VALUE;
                                        next_dp[new_tight][new_nonzero][new_diff] <= temp_sum;
                                    end
                                end
                            end
                            
                            if (curr_digit ==4'd9) begin
                                curr_digit <=4'd0;
                                if (curr_diff ==6'd32) begin
                                    curr_diff <=6'd0;
                                    curr_tight <= curr_tight +1'b1;
                                end else begin
                                    curr_diff <= curr_diff +1'b1;
                                end
                            end else begin
                                curr_digit <= curr_digit +1'b1;
                            end
                        end
                        
                        if (curr_tight ==2'd2) begin
                            loop_done <=1'b1;
                        end
                    end else begin
                        for (i=0; i<2; i=i+1) begin
                            for (j=0; j<2; j=j+1) begin
                                for (k=0; k<33; k=k+1) begin
                                    current_dp[i][j][k] <= next_dp[i][j][k];
                                    next_dp[i][j][k] <=30'd0;
                                end
                            end
                        end
                        
                        if (position ==5'd15) begin
                            result_f_L <= (current_dp[0][1][16] + current_dp[1][1][16]) % MOD_VALUE;
                            next_state <= STORE_L;
                        end else begin
                            position <= position +1'b1;
                            curr_tight <=2'd0;
                            curr_diff <=6'd0;
                            curr_digit <=4'd0;
                            loop_done <=1'b0;
                        end
                    end
                end
                
                STORE_L: begin
                    next_state <= SUBTRACT;
                end
                
                SUBTRACT: begin
                    if (result_f_R >= result_f_L) begin
                        sub_result <= (result_f_R - result_f_L) % MOD_VALUE;
                    end else begin
                        sub_result <= (result_f_R + MOD_VALUE - result_f_L) % MOD_VALUE;
                    end
                    next_state <= FINISH;
                end
                
                FINISH: begin
                    count <= sub_result;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule