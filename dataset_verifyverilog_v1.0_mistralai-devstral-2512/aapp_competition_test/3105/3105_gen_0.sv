module LexSmallestPair(
    input clk,
    input rst_n,
    input start,
    input [9:0] data_in,
    input data_valid,
    output reg [9:0] A_out,
    output reg [9:0] B_out,
    output reg done,
    output reg found
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COLLECTING = 2'd1;
    localparam [1:0] SEARCHING = 2'd2;
    localparam [1:0] DONE = 2'd3;
    
    reg [1:0] state;
    reg [9:0] position;
    reg [9:0] first_A_pos [0:1023];
    reg [9:0] first_B_after_first_A [0:1023][0:1023];
    reg [9:0] second_A_after_first_B [0:1023][0:1023];
    reg [9:0] current_A;
    reg [9:0] current_B;
    reg [9:0] i;
    reg [9:0] j;
    reg found_pair;
    reg [9:0] min_A;
    reg [9:0] min_B;
    reg [9:0] temp_A;
    reg [9:0] temp_B;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            position <= 10'd0;
            done <= 1'b0;
            found <= 1'b0;
            found_pair <= 1'b0;
            min_A <= 10'd0;
            min_B <= 10'd0;
            i <= 10'd0;
            j <= 10'd0;
            current_A <= 10'd0;
            current_B <= 10'd0;
            temp_A <= 10'd0;
            temp_B <= 10'd0;
            
            // Initialize arrays
            integer k;
            for (k = 0; k < 1024; k = k + 1) begin
                first_A_pos[k] <= 10'd0;
                integer m;
                for (m = 0; m < 1024; m = m + 1) begin
                    first_B_after_first_A[k][m] <= 10'd0;
                    second_A_after_first_B[k][m] <= 10'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    found <= 1'b0;
                    if (start) begin
                        state <= COLLECTING;
                        position <= 10'd0;
                        found_pair <= 1'b0;
                        min_A <= 10'd0;
                        min_B <= 10'd0;
                        i <= 10'd0;
                        j <= 10'd0;
                        current_A <= 10'd0;
                        current_B <= 10'd0;
                        temp_A <= 10'd0;
                        temp_B <= 10'd0;
                        
                        // Initialize arrays
                        integer k;
                        for (k = 0; k < 1024; k = k + 1) begin
                            first_A_pos[k] <= 10'd0;
                            integer m;
                            for (m = 0; m < 1024; m = m + 1) begin
                                first_B_after_first_A[k][m] <= 10'd0;
                                second_A_after_first_B[k][m] <= 10'd0;
                            end
                        end
                    end
                end
                
                COLLECTING: begin
                    if (data_valid) begin
                        position <= position + 10'd1;
                        current_A <= data_in;
                        
                        // Check if current value completes any pattern
                        integer k;
                        for (k = 0; k < 1024; k = k + 1) begin
                            if (first_A_pos[k] != 10'd0) begin
                                integer m;
                                for (m = 0; m < 1024; m = m + 1) begin
                                    if (first_B_after_first_A[m][k] != 10'd0 && data_in == k && position > first_B_after_first_A[m][k]) begin
                                        second_A_after_first_B[k][m] <= position;
                                        found_pair <= 1'b1;
                                    end
                                end
                            end
                        end
                        
                        // Update first_A_pos if not set
                        if (first_A_pos[current_A] == 10'd0) begin
                            first_A_pos[current_A] <= position;
                        end
                        
                        // Update first_B_after_first_A for all A values
                        integer l;
                        for (l = 0; l < 1024; l = l + 1) begin
                            if (first_A_pos[l] != 10'd0 && l != current_A) begin
                                if (first_B_after_first_A[current_A][l] == 10'd0) begin
                                    first_B_after_first_A[current_A][l] <= position;
                                end
                            end
                        end
                        
                        // Check if we've reached the end of input
                        if (position == 10'd1023) begin
                            state <= SEARCHING;
                            i <= 10'd0;
                            j <= 10'd0;
                        end
                    end
                end
                
                SEARCHING: begin
                    // Search for lexicographically smallest pair
                    if (i == 10'd0 && j == 10'd0) begin
                        min_A <= 10'd1024;
                        min_B <= 10'd1024;
                    end
                    
                    if (j < 10'd1024) begin
                        if (i < 10'd1024 && i != j) begin
                            if (first_A_pos[i] != 10'd0 && first_B_after_first_A[j][i] != 10'd0 && second_A_after_first_B[i][j] != 10'd0) begin
                                if (i < min_A || (i == min_A && j < min_B)) begin
                                    min_A <= i;
                                    min_B <= j;
                                end
                            end
                            i <= i + 10'd1;
                        end else begin
                            i <= 10'd0;
                            j <= j + 10'd1;
                        end
                    end else begin
                        if (min_A != 10'd1024 && min_B != 10'd1024) begin
                            found <= 1'b1;
                            A_out <= min_A;
                            B_out <= min_B;
                        end else begin
                            found <= 1'b0;
                        end
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule