module SymmetricDifference(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr1 [0:15],
    input wire [7:0] arr2 [0:15],
    input wire [3:0] len1,
    input wire [3:0] len2,
    output reg [7:0] result [0:31],
    output reg [4:0] result_len,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CAPTURE = 3'd1;
    localparam [2:0] REMOVE_DUP1 = 3'd2;
    localparam [2:0] REMOVE_DUP2 = 3'd3;
    localparam [2:0] COMPARE = 3'd4;
    localparam [2:0] SORT = 3'd5;
    localparam [2:0] OUTPUT = 3'd6;
    localparam [2:0] DONE_STATE = 3'd7;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Internal registers for processing
    reg [7:0] unique1 [0:15];
    reg [7:0] unique2 [0:15];
    reg [3:0] unique1_len;
    reg [3:0] unique2_len;
    reg [7:0] temp_result [0:31];
    reg [4:0] temp_result_len;

    // Temporary registers for processing
    reg [7:0] current_elem;
    reg [3:0] i, j, k;
    reg found;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            done <= 1'b0;
            result_len <= 5'd0;
            unique1_len <= 4'd0;
            unique2_len <= 4'd0;
            temp_result_len <= 5'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            found <= 1'b0;
            current_elem <= 8'd0;
            
            // Initialize all result registers
            for (i = 0; i < 32; i = i + 1) begin
                result[i] <= 8'd0;
                temp_result[i] <= 8'd0;
            end
            
            // Initialize unique arrays
            for (i = 0; i < 16; i = i + 1) begin
                unique1[i] <= 8'd0;
                unique2[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= CAPTURE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CAPTURE: begin
                    // Copy input arrays to internal registers
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < len1) begin
                            unique1[i] <= arr1[i];
                        end else begin
                            unique1[i] <= 8'd0;
                        end
                        
                        if (i < len2) begin
                            unique2[i] <= arr2[i];
                        end else begin
                            unique2[i] <= 8'd0;
                        end
                    end
                    unique1_len <= len1;
                    unique2_len <= len2;
                    next_state <= REMOVE_DUP1;
                end

                REMOVE_DUP1: begin
                    // Remove duplicates from unique1
                    for (i = 0; i < unique1_len; i = i + 1) begin
                        found <= 1'b0;
                        for (j = 0; j < i; j = j + 1) begin
                            if (unique1[i] == unique1[j]) begin
                                found <= 1'b1;
                            end
                        end
                        
                        if (found) begin
                            // Shift remaining elements left
                            for (j = i; j < unique1_len - 1; j = j + 1) begin
                                unique1[j] <= unique1[j + 1];
                            end
                            unique1_len <= unique1_len - 1;
                            i <= i - 1; // Re-check current position
                        end
                    end
                    next_state <= REMOVE_DUP2;
                end

                REMOVE_DUP2: begin
                    // Remove duplicates from unique2
                    for (i = 0; i < unique2_len; i = i + 1) begin
                        found <= 1'b0;
                        for (j = 0; j < i; j = j + 1) begin
                            if (unique2[i] == unique2[j]) begin
                                found <= 1'b1;
                            end
                        end
                        
                        if (found) begin
                            // Shift remaining elements left
                            for (j = i; j < unique2_len - 1; j = j + 1) begin
                                unique2[j] <= unique2[j + 1];
                            end
                            unique2_len <= unique2_len - 1;
                            i <= i - 1; // Re-check current position
                        end
                    end
                    next_state <= COMPARE;
                end

                COMPARE: begin
                    // Find elements that are in only one array
                    temp_result_len <= 5'd0;
                    
                    // Check elements in unique1
                    for (i = 0; i < unique1_len; i = i + 1) begin
                        found <= 1'b0;
                        for (j = 0; j < unique2_len; j = j + 1) begin
                            if (unique1[i] == unique2[j]) begin
                                found <= 1'b1;
                            end
                        end
                        
                        if (!found) begin
                            temp_result[temp_result_len] <= unique1[i];
                            temp_result_len <= temp_result_len + 1;
                        end
                    end
                    
                    // Check elements in unique2
                    for (i = 0; i < unique2_len; i = i + 1) begin
                        found <= 1'b0;
                        for (j = 0; j < unique1_len; j = j + 1) begin
                            if (unique2[i] == unique1[j]) begin
                                found <= 1'b1;
                            end
                        end
                        
                        if (!found) begin
                            temp_result[temp_result_len] <= unique2[i];
                            temp_result_len <= temp_result_len + 1;
                        end
                    end
                    
                    next_state <= SORT;
                end

                SORT: begin
                    // Bubble sort the result
                    for (i = 0; i < temp_result_len - 1; i = i + 1) begin
                        for (j = 0; j < temp_result_len - i - 1; j = j + 1) begin
                            if (temp_result[j] > temp_result[j + 1]) begin
                                current_elem <= temp_result[j];
                                temp_result[j] <= temp_result[j + 1];
                                temp_result[j + 1] <= current_elem;
                            end
                        end
                    end
                    next_state <= OUTPUT;
                end

                OUTPUT: begin
                    // Copy sorted result to output
                    for (i = 0; i < 32; i = i + 1) begin
                        if (i < temp_result_len) begin
                            result[i] <= temp_result[i];
                        end else begin
                            result[i] <= 8'd0;
                        end
                    end
                    result_len <= temp_result_len;
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
            
            // Cycle counter for safety
            if (state != IDLE && state != DONE_STATE) begin
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    next_state <= IDLE;
                end
            end
        end
    end

endmodule