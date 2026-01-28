module KeyCombinationSum(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [2:0] k_select,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    // Constants
    localparam [31:0] MODULUS = 32'd1000000007;
    localparam [2:0] MAX_K = 3'd3;
    localparam [2:0] MAX_N = 3'd7;
    
    // Internal registers
    reg [2:0] state;
    reg [7:0] captured_arr [0:7];
    reg [2:0] captured_k;
    reg [31:0] sum_accumulator;
    reg [5:0] combination_counter;
    reg [7:0] current_max;
    reg [7:0] temp_max;
    reg [7:0] combination_indices [0:2];
    reg [2:0] index_ptr;
    reg [2:0] element_ptr;
    reg [2:0] bit_counter;
    reg [7:0] bit_pattern;
    reg [2:0] bit_index;
    reg [2:0] combination_index;
    reg [2:0] max_index;
    reg [7:0] current_value;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            sum_accumulator <= 32'd0;
            combination_counter <= 6'd0;
            current_max <= 8'd0;
            temp_max <= 8'd0;
            index_ptr <= 3'd0;
            element_ptr <= 3'd0;
            bit_counter <= 3'd0;
            bit_pattern <= 8'd0;
            bit_index <= 3'd0;
            combination_index <= 3'd0;
            max_index <= 3'd0;
            current_value <= 8'd0;
            
            // Initialize captured array
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                captured_arr[i] <= 8'd0;
            end
            captured_k <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Capture inputs
                        integer i;
                        for (i = 0; i < 8; i = i + 1) begin
                            captured_arr[i] <= arr[i];
                        end
                        captured_k <= k_select;
                        
                        // Initialize computation
                        sum_accumulator <= 32'd0;
                        combination_counter <= 6'd0;
                        bit_pattern <= 8'd0;
                        bit_index <= 3'd0;
                        combination_index <= 3'd0;
                        
                        // Check for edge cases
                        if (captured_k == 3'd0 || captured_k > 3'd3) begin
                            state <= FINISH;
                        end else begin
                            state <= COMPUTE;
                        end
                    end
                end
                
                COMPUTE: begin
                    // Generate combinations using bit patterns
                    if (bit_index == 3'd0) begin
                        // Start new combination
                        if (combination_counter == 6'd0) begin
                            bit_pattern <= 8'd0;
                        end
                        
                        // Find next bit pattern with exactly K bits set
                        reg found;
                        reg [7:0] pattern;
                        pattern = bit_pattern;
                        found = 1'b0;
                        
                        while (!found && pattern < 8'd256) begin
                            pattern = pattern + 8'd1;
                            
                            // Count number of set bits
                            reg [3:0] bit_count;
                            reg [7:0] temp_pattern;
                            integer j;
                            temp_pattern = pattern;
                            bit_count = 4'd0;
                            
                            for (j = 0; j < 8; j = j + 1) begin
                                if (temp_pattern[0]) begin
                                    bit_count = bit_count + 4'd1;
                                end
                                temp_pattern = temp_pattern >> 1;
                            end
                            
                            if (bit_count == captured_k) begin
                                found = 1'b1;
                            end
                        end
                        
                        if (found) begin
                            bit_pattern <= pattern;
                            combination_counter <= combination_counter + 6'd1;
                            bit_index <= 3'd0;
                            combination_index <= 3'd0;
                            current_max <= 8'd0;
                        end else begin
                            // All combinations processed
                            state <= FINISH;
                        end
                    end
                    
                    if (bit_index < 3'd8 && combination_index < captured_k) begin
                        // Check if current bit is set
                        if (bit_pattern[bit_index]) begin
                            // Store the index
                            combination_indices[combination_index] <= bit_index;
                            combination_index <= combination_index + 3'd1;
                            
                            // Update current max
                            current_value <= captured_arr[bit_index];
                            if (current_value > current_max) begin
                                current_max <= current_value;
                            end
                        end
                        bit_index <= bit_index + 3'd1;
                    end else if (combination_index == captured_k) begin
                        // Add current max to accumulator
                        sum_accumulator <= (sum_accumulator + current_max) % MODULUS;
                        bit_index <= 3'd0;
                        combination_index <= 3'd0;
                    end
                    
                    // Check if all combinations are processed
                    if (combination_counter >= 6'd56 && captured_k == 3'd3) begin
                        state <= FINISH;
                    end else if (combination_counter >= 6'd28 && captured_k == 3'd2) begin
                        state <= FINISH;
                    end else if (combination_counter >= 6'd8 && captured_k == 3'd1) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= sum_accumulator;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Combinational logic for finding max in combination
    always @(*) begin
        if (state == COMPUTE && combination_index > 3'd0) begin
            temp_max = 8'd0;
            integer i;
            for (i = 0; i < combination_index; i = i + 1) begin
                if (captured_arr[combination_indices[i]] > temp_max) begin
                    temp_max = captured_arr[combination_indices[i]];
                end
            end
            current_max = temp_max;
        end
    end

endmodule