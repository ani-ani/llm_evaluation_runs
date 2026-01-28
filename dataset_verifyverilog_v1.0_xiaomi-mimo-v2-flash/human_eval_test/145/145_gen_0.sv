module SortByDigitSum(
    input clk,
    input rst_n,
    input start,
    input signed [7:0] in_0,
    input signed [7:0] in_1,
    input signed [7:0] in_2,
    input signed [7:0] in_3,
    input signed [7:0] in_4,
    input signed [7:0] in_5,
    input signed [7:0] in_6,
    input signed [7:0] in_7,
    output reg signed [7:0] out_0,
    output reg signed [7:0] out_1,
    output reg signed [7:0] out_2,
    output reg signed [7:0] out_3,
    output reg signed [7:0] out_4,
    output reg signed [7:0] out_5,
    output reg signed [7:0] out_6,
    output reg signed [7:0] out_7,
    output reg done
);

// State declarations
localparam [2:0] IDLE = 3'd0;
localparam [2:0] CALC_DIGIT_0 = 3'd1;
localparam [2:0] CALC_DIGIT_1 = 3'd2;
localparam [2:0] SORTING = 3'd3;
localparam [2:0] FINISH = 3'd4;

reg [2:0] state;
reg [4:0] sort_counter; // 0-16 for sorting network stages
reg [2:0] digit_idx; // For digit calculation
reg [3:0] calc_idx; // For which input we're calculating

// Internal registers
reg signed [7:0] val_reg [0:7];
reg [4:0] digit_sum_reg [0:7];
reg [2:0] orig_idx_reg [0:7];

// Temporary registers for sorting
reg signed [7:0] temp_val;
reg [4:0] temp_digit;
reg [2:0] temp_idx;

// For digit calculation
reg [7:0] abs_val;
reg [7:0] digit_temp;
reg [7:0] mod_temp;

reg [4:0] new_digit_sum;
reg [7:0] new_abs_val;

integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        sort_counter <= 5'd0;
        calc_idx <= 4'd0;
        digit_idx <= 3'd0;
        for (i = 0; i < 8; i = i + 1) begin
            val_reg[i] <= 8'd0;
            digit_sum_reg[i] <= 5'd0;
            orig_idx_reg[i] <= 3'd0;
        end
        out_0 <= 8'd0;
        out_1 <= 8'd0;
        out_2 <= 8'd0;
        out_3 <= 8'd0;
        out_4 <= 8'd0;
        out_5 <= 8'd0;
        out_6 <= 8'd0;
        out_7 <= 8'd0;
        abs_val <= 8'd0;
        digit_temp <= 8'd0;
        mod_temp <= 8'd0;
        new_digit_sum <= 5'd0;
        new_abs_val <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                sort_counter <= 5'd0;
                calc_idx <= 4'd0;
                digit_idx <= 3'd0;
                if (start) begin
                    // Store inputs and indices
                    val_reg[0] <= in_0;
                    val_reg[1] <= in_1;
                    val_reg[2] <= in_2;
                    val_reg[3] <= in_3;
                    val_reg[4] <= in_4;
                    val_reg[5] <= in_5;
                    val_reg[6] <= in_6;
                    val_reg[7] <= in_7;
                    for (i = 0; i < 8; i = i + 1) begin
                        orig_idx_reg[i] <= i;
                        digit_sum_reg[i] <= 5'd0;
                    end
                    state <= CALC_DIGIT_0;
                    calc_idx <= 4'd0;
                    digit_idx <= 3'd0;
                    // Start with first number
                    abs_val <= (in_0 >= 0) ? in_0 : (-in_0);
                    new_digit_sum <= 5'd0;
                    new_abs_val <= (in_0 >= 0) ? in_0 : (-in_0);
                end
            end
            
            CALC_DIGIT_0: begin
                // First digit calculation cycle
                // Current abs_val is ready
                digit_temp <= abs_val % 8'd10;
                mod_temp <= abs_val / 8'd10;
                state <= CALC_DIGIT_1;
            end
            
            CALC_DIGIT_1: begin
                // Second cycle: add digit and update
                new_digit_sum <= new_digit_sum + digit_temp;
                new_abs_val <= mod_temp;
                abs_val <= mod_temp;
                
                if (mod_temp == 8'd0) begin
                    // Done with current number
                    digit_sum_reg[calc_idx] <= new_digit_sum + digit_temp;
                    
                    if (calc_idx == 4'd7) begin
                        state <= SORTING;
                        sort_counter <= 5'd0;
                    end else begin
                        calc_idx <= calc_idx + 4'd1;
                        state <= CALC_DIGIT_0;
                        // Setup next number
                        digit_idx <= 3'd0;
                        new_digit_sum <= 5'd0;
                        case (calc_idx + 1)
                            4'd0: abs_val <= (in_0 >= 0) ? in_0 : (-in_0);
                            4'd1: abs_val <= (in_1 >= 0) ? in_1 : (-in_1);
                            4'd2: abs_val <= (in_2 >= 0) ? in_2 : (-in_2);
                            4'd3: abs_val <= (in_3 >= 0) ? in_3 : (-in_3);
                            4'd4: abs_val <= (in_4 >= 0) ? in_4 : (-in_4);
                            4'd5: abs_val <= (in_5 >= 0) ? in_5 : (-in_5);
                            4'd6: abs_val <= (in_6 >= 0) ? in_6 : (-in_6);
                            4'd7: abs_val <= (in_7 >= 0) ? in_7 : (-in_7);
                        endcase
                    end
                end
            end
            
            SORTING: begin
                // Odd-even transposition sort
                if (sort_counter < 5'd16) begin
                    case (sort_counter)
                        // Compare pairs (0,1), (2,3), (4,5), (6,7)
                        5'd0: begin // Even phase 0
                            // Compare (0,1)
                            if (digit_sum_reg[1] < digit_sum_reg[0] || 
                                (digit_sum_reg[1] == digit_sum_reg[0] && orig_idx_reg[1] < orig_idx_reg[0])) begin
                                swap(0, 1);
                            end
                            // Compare (2,3)
                            if (digit_sum_reg[3] < digit_sum_reg[2] || 
                                (digit_sum_reg[3] == digit_sum_reg[2] && orig_idx_reg[3] < orig_idx_reg[2])) begin
                                swap(2, 3);
                            end
                            // Compare (4,5)
                            if (digit_sum_reg[5] < digit_sum_reg[4] || 
                                (digit_sum_reg[5] == digit_sum_reg[4] && orig_idx_reg[5] < orig_idx_reg[4])) begin
                                swap(4, 5);
                            end
                            // Compare (6,7)
                            if (digit_sum_reg[7] < digit_sum_reg[6] || 
                                (digit_sum_reg[7] == digit_sum_reg[6] && orig_idx_reg[7] < orig_idx_reg[6])) begin
                                swap(6, 7);
                            end
                            sort_counter <= sort_counter + 5'd1;
                        end
                        
                        5'd1: begin // Odd phase 1
                            // Compare (1,2), (3,4), (5,6)
                            if (digit_sum_reg[2] < digit_sum_reg[1] || 
                                (digit_sum_reg[2] == digit_sum_reg[1] && orig_idx_reg[2] < orig_idx_reg[1])) begin
                                swap(1, 2);
                            end
                            if (digit_sum_reg[4] < digit_sum_reg[3] || 
                                (digit_sum_reg[4] == digit_sum_reg[3] && orig_idx_reg[4] < orig_idx_reg[3])) begin
                                swap(3, 4);
                            end
                            if (digit_sum_reg[6] < digit_sum_reg[5] || 
                                (digit_sum_reg[6] == digit_sum_reg[5] && orig_idx_reg[6] < orig_idx_reg[5])) begin
                                swap(5, 6);
                            end
                            sort_counter <= sort_counter + 5'd1;
                        end
                        
                        5'd2: begin // Even phase 2
                            // Compare (0,1), (2,3), (4,5), (6,7)
                            if (digit_sum_reg[1] < digit_sum_reg[0] || 
                                (digit_sum_reg[1] == digit_sum_reg[0] && orig_idx_reg[1] < orig_idx_reg[0])) begin
                                swap(0, 1);
                            end
                            if (digit_sum_reg[3] < digit_sum_reg[2] || 
                                (digit_sum_reg[3] == digit_sum_reg[2] && orig_idx_reg[3] < orig_idx_reg[2])) begin
                                swap(2, 3);
                            end
                            if (digit_sum_reg[5] < digit_sum_reg[4] || 
                                (digit_sum_reg[5] == digit_sum_reg[4] && orig_idx_reg[5] < orig_idx_reg[4])) begin
                                swap(4, 5);
                            end
                            if (digit_sum_reg[7] < digit_sum_reg[6] || 
                                (digit_sum_reg[7] == digit_sum_reg[6] && orig_idx_reg[7] < orig_idx_reg[6])) begin
                                swap(6, 7);
                            end
                            sort_counter <= sort_counter + 5'd1;
                        end
                        
                        5'd3: begin // Odd phase 3
                            if (digit_sum_reg[2] < digit_sum_reg[1] || 
                                (digit_sum_reg[2] == digit_sum_reg[1] && orig_idx_reg[2] < orig_idx_reg[1])) begin
                                swap(1, 2);
                            end
                            if (digit_sum_reg[4] < digit_sum_reg[3] || 
                                (digit_sum_reg[4] == digit_sum_reg[3] && orig_idx_reg[4] < orig_idx_reg[3])) begin
                                swap(3, 4);
                            end
                            if (digit_sum_reg[6] < digit_sum_reg[5] || 
                                (digit_sum_reg[6] == digit_sum_reg[5] && orig_idx_reg[6] < orig_idx_reg[5])) begin
                                swap(5, 6);
                            end
                            sort_counter <= sort_counter + 5'd1;
                        end
                        
                        5'd4: begin // Even phase 4
                            if (digit_sum_reg[1] < digit_sum_reg[0] || 
                                (digit_sum_reg[1] == digit_sum_reg[0] && orig_idx_reg[1] < orig_idx_reg[0])) begin
                                swap(0, 1);
                            end
                            if (digit_sum_reg[3] < digit_sum_reg[2] || 
                                (digit_sum_reg[3] == digit_sum_reg[2] && orig_idx_reg[3] < orig_idx_reg[2])) begin
                                swap(2, 3);
                            end
                            if (digit_sum_reg[5] < digit_sum_reg[4] || 
                                (digit_sum_reg[5] == digit_sum_reg[4] && orig_idx_reg[5] < orig_idx_reg[4])) begin
                                swap(4, 5);
                            end
                            if (digit_sum_reg[7] < digit_sum_reg[6] || 
                                (digit_sum_reg[7] == digit_sum_reg[6] && orig_idx_reg[7] < orig_idx_reg[6])) begin
                                swap(6, 7);
                            end
                            sort_counter <= sort_counter + 5'd1;
                        end
                        
                        5'd5: begin // Odd phase 5
                            if (digit_sum_reg[2] < digit_sum_reg[1] || 
                                (digit_sum_reg[2] == digit_sum_reg[1] && orig_idx_reg[2] < orig_idx_reg[1])) begin
                                swap(1, 2);
                            end
                            if (digit_sum_reg[4] < digit_sum_reg[3] || 
                                (digit_sum_reg[4] == digit_sum_reg[3] && orig_idx_reg[4] < orig_idx_reg[3])) begin
                                swap(3, 4);
                            end
                            if (digit_sum_reg[6] < digit_sum_reg[5] || 
                                (digit_sum_reg[6] == digit_sum_reg[5] && orig_idx_reg[6] < orig_idx_reg[5])) begin
                                swap(5, 6);
                            end
                            sort_counter <= sort_counter + 5'd1;
                        end
                        
                        5'd6: begin // Even phase 6
                            if (digit_sum_reg[1] < digit_sum_reg[0] || 
                                (digit_sum_reg[1] == digit_sum_reg[0] && orig_idx_reg[1] < orig_idx_reg[0])) begin
                                swap(0, 1);
                            end
                            if (digit_sum_reg[3] < digit_sum_reg[2] || 
                                (digit_sum_reg[3] == digit_sum_reg[2] && orig_idx_reg[3] < orig_idx_reg[2])) begin
                                swap(2, 3);
                            end
                            if (digit_sum_reg[5] < digit_sum_reg[4] || 
                                (digit_sum_reg[5] == digit_sum_reg[4] && orig_idx_reg[5] < orig_idx_reg[4])) begin
                                swap(4, 5);
                            end
                            if (digit_sum_reg[7] < digit_sum_reg[6] || 
                                (digit_sum_reg[7] == digit_sum_reg[6] && orig_idx_reg[7] < orig_idx_reg[6])) begin
                                swap(6, 7);
                            end
                            sort_counter <= sort_counter + 5'd1;
                        end
                        
                        5'd7: begin // Odd phase 7
                            if (digit_sum_reg[2] < digit_sum_reg[1] || 
                                (digit_sum_reg[2] == digit_sum_reg[1] && orig_idx_reg[2] < orig_idx_reg[1])) begin
                                swap(1, 2);
                            end
                            if (digit_sum_reg[4] < digit_sum_reg[3] || 
                                (digit_sum_reg[4] == digit_sum_reg[3] && orig_idx_reg[4] < orig_idx_reg[3])) begin
                                swap(3, 4);
                            end
                            if (digit_sum_reg[6] < digit_sum_reg[5] || 
                                (digit_sum_reg[6] == digit_sum_reg[5] && orig_idx_reg[6] < orig_idx_reg[5])) begin
                                swap(5, 6);
                            end
                            sort_counter <= sort_counter + 5'd1;
                        end
                        
                        5'd8: begin // Even phase 8
                            if (digit_sum_reg[1] < digit_sum_reg[0] || 
                                (digit_sum_reg[1] == digit_sum_reg[0] && orig_idx_reg[1] < orig_idx_reg[0])) begin
                                swap(0, 1);
                            end
                            if (digit_sum_reg[3] < digit_sum_reg[2] || 
                                (digit_sum_reg[3] == digit_sum_reg[2] && orig_idx_reg[3] < orig_idx_reg[2])) begin
                                swap(2, 3);
                            end
                            if (digit_sum_reg[5] < digit_sum_reg[4] || 
                                (digit_sum_reg[5] == digit_sum_reg[4] && orig_idx_reg[5] < orig_idx_reg[4])) begin
                                swap(4, 5);
                            end
                            if (digit_sum_reg[7] < digit_sum_reg[6] || 
                                (digit_sum_reg[7] == digit_sum_reg[6] && orig_idx_reg[7] < orig_idx_reg[6])) begin
                                swap(6, 7);
                            end
                            sort_counter <= sort_counter + 5'd1;
                        end
                        
                        5'd9: begin // Odd phase 9
                            if (digit_sum_reg[2] < digit_sum_reg[1] || 
                                (digit_sum_reg[2] == digit_sum_reg[1] && orig_idx_reg[2] < orig_idx_reg[1])) begin
                                swap(1, 2);
                            end
                            if (digit_sum_reg[4] < digit_sum_reg[3] || 
                                (digit_sum_reg[4] == digit_sum_reg[3] && orig_idx_reg[4] < orig_idx_reg[3])) begin
                                swap(3, 4);
                            end
                            if (digit_sum_reg[6] < digit_sum_reg[5] || 
                                (digit_sum_reg[6] == digit_sum_reg[5] && orig_idx_reg[6] < orig_idx_reg[5])) begin
                                swap(5, 6);
                            end
                            sort_counter <= sort_counter + 5'd1;
                        end
                        
                        5'd10: begin // Even phase 10
                            if (digit_sum_reg[1] < digit_sum_reg[0] || 
                                (digit_sum_reg[1] == digit_sum_reg[0] && orig_idx_reg[1] < orig_idx_reg[0])) begin
                                swap(0, 1);
                            end
                            if (digit_sum_reg[3] < digit_sum_reg[2] || 
                                (digit_sum_reg[3] == digit_sum_reg[2] && orig_idx_reg[3] < orig_idx_reg[2])) begin
                                swap(2, 3);
                            end
                            if (digit_sum_reg[5] < digit_sum_reg[4] || 
                                (digit_sum_reg[5] == digit_sum_reg[4] && orig_idx_reg[5] < orig_idx_reg[4])) begin
                                swap(4, 5);
                            end
                            if (digit_sum_reg[7] < digit_sum_reg[6] || 
                                (digit_sum_reg[7] == digit_sum_reg[6] && orig_idx_reg[7] < orig_idx_reg[6])) begin
                                swap(6, 7);
                            end
                            sort_counter <= sort_counter + 5'd1;
                        end
                        
                        5'd11: begin // Odd phase 11
                            if (digit_sum_reg[2] < digit_sum_reg[1] || 
                                (digit_sum_reg[2] == digit_sum_reg[1] && orig_idx_reg[2] < orig_idx_reg[1])) begin
                                swap(1, 2);
                            end
                            if (digit_sum_reg[4] < digit_sum_reg[3] || 
                                (digit_sum_reg[4] == digit_sum_reg[3] && orig_idx_reg[4] < orig_idx_reg[3])) begin
                                swap(3, 4);
                            end
                            if (digit_sum_reg[6] < digit_sum_reg[5] || 
                                (digit_sum_reg[6] == digit_sum_reg[5] && orig_idx_reg[6] < orig_idx_reg[5])) begin
                                swap(5, 6);
                            end
                            sort_counter <= sort_counter + 5'd1;
                        end
                        
                        5'd12: begin // Even phase 12
                            if (digit_sum_reg[1] < digit_sum_reg[0] || 
                                (digit_sum_reg[1] == digit_sum_reg[0] && orig_idx_reg[1] < orig_idx_reg[0])) begin
                                swap(0, 1);
                            end
                            if (digit_sum_reg[3] < digit_sum_reg[2] || 
                                (digit_sum_reg[3] == digit_sum_reg[2] && orig_idx_reg[3] < orig_idx_reg[2])) begin
                                swap(2, 3);
                            end
                            if (digit_sum_reg[5] < digit_sum_reg[4] || 
                                (digit_sum_reg[5] == digit_sum_reg[4] && orig_idx_reg[5] < orig_idx_reg[4])) begin
                                swap(4, 5);
                            end
                            if (digit_sum_reg[7] < digit_sum_reg[6] || 
                                (digit_sum_reg[7] == digit_sum_reg[6] && orig_idx_reg[7] < orig_idx_reg[6])) begin
                                swap(6, 7);
                            end
                            sort_counter <= sort_counter + 5'd1;
                        end
                        
                        5'd13: begin // Odd phase 13
                            if (digit_sum_reg[2] < digit_sum_reg[1] || 
                                (digit_sum_reg[2] == digit_sum_reg[1] && orig_idx_reg[2] < orig_idx_reg[1])) begin
                                swap(1, 2);
                            end
                            if (digit_sum_reg[4] < digit_sum_reg[3] || 
                                (digit_sum_reg[4] == digit_sum_reg[3] && orig_idx_reg[4] < orig_idx_reg[3])) begin
                                swap(3, 4);
                            end
                            if (digit_sum_reg[6] < digit_sum_reg[5] || 
                                (digit_sum_reg[6] == digit_sum_reg[5] && orig_idx_reg[6] < orig_idx_reg[5])) begin
                                swap(5, 6);
                            end
                            sort_counter <= sort_counter + 5'd1;
                        end
                        
                        5'd14: begin // Even phase 14
                            if (digit_sum_reg[1] < digit_sum_reg[0] || 
                                (digit_sum_reg[1] == digit_sum_reg[0] && orig_idx_reg[1] < orig_idx_reg[0])) begin
                                swap(0, 1);
                            end
                            if (digit_sum_reg[3] < digit_sum_reg[2] || 
                                (digit_sum_reg[3] == digit_sum_reg[2] && orig_idx_reg[3] < orig_idx_reg[2])) begin
                                swap(2, 3);
                            end
                            if (digit_sum_reg[5] < digit_sum_reg[4] || 
                                (digit_sum_reg[5] == digit_sum_reg[4] && orig_idx_reg[5] < orig_idx_reg[4])) begin
                                swap(4, 5);
                            end
                            if (digit_sum_reg[7] < digit_sum_reg[6] || 
                                (digit_sum_reg[7] == digit_sum_reg[6] && orig_idx_reg[7] < orig_idx_reg[6])) begin
                                swap(6, 7);
                            end
                            sort_counter <= sort_counter + 5'd1;
                        end
                        
                        5'd15: begin // Odd phase 15
                            if (digit_sum_reg[2] < digit_sum_reg[1] || 
                                (digit_sum_reg[2] == digit_sum_reg[1] && orig_idx_reg[2] < orig_idx_reg[1])) begin
                                swap(1, 2);
                            end
                            if (digit_sum_reg[4] < digit_sum_reg[3] || 
                                (digit_sum_reg[4] == digit_sum_reg[3] && orig_idx_reg[4] < orig_idx_reg[3])) begin
                                swap(3, 4);
                            end
                            if (digit_sum_reg[6] < digit_sum_reg[5] || 
                                (digit_sum_reg[6] == digit_sum_reg[5] && orig_idx_reg[6] < orig_idx_reg[5])) begin
                                swap(5, 6);
                            end
                            sort_counter <= sort_counter + 5'd1;
                        end
                        
                        default: begin
                            sort_counter <= 5'd16;
                        end
                    endcase
                end
                
                if (sort_counter >= 5'd16) begin
                    state <= FINISH;
                end
            end
            
            FINISH: begin
                // Output the sorted values
                out_0 <= val_reg[0];
                out_1 <= val_reg[1];
                out_2 <= val_reg[2];
                out_3 <= val_reg[3];
                out_4 <= val_reg[4];
                out_5 <= val_reg[5];
                out_6 <= val_reg[6];
                out_7 <= val_reg[7];
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

// Task for swapping elements
task swap(input [2:0] i, input [2:0] j);
    begin
        temp_val <= val_reg[i];
        val_reg[i] <= val_reg[j];
        val_reg[j] <= temp_val;
        
        temp_digit <= digit_sum_reg[i];
        digit_sum_reg[i] <= digit_sum_reg[j];
        digit_sum_reg[j] <= temp_digit;
        
        temp_idx <= orig_idx_reg[i];
        orig_idx_reg[i] <= orig_idx_reg[j];
        orig_idx_reg[j] <= temp_idx;
    end
endtask

endmodule