module unsorted_permutations(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [47:0] data_in,
    output reg [31:0] result,
    output reg done
);
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    // Constants
    localparam [31:0] MOD = 32'd1000000009;
    localparam [3:0] N = 4'd12;
    
    // Registers
    reg [2:0] state;
    reg [7:0] cycle_count;
    reg [3:0] pos_idx;
    reg [3:0] prev_idx;
    reg [11:0] mask;
    reg [31:0] dp_table [0:11][0:11][0:4095];
    reg [3:0] sorted_arr [0:11];
    reg [3:0] input_arr [0:11];
    reg [31:0] temp_result;
    
    // Parse input array
    integer i, j, k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            pos_idx <= 4'd0;
            prev_idx <= 4'd0;
            mask <= 12'd0;
            done <= 1'b0;
            result <= 32'd0;
            temp_result <= 32'd0;
            
            // Initialize DP table
            for (i = 0; i < 12; i = i + 1) begin
                for (j = 0; j < 12; j = j + 1) begin
                    for (k = 0; k < 4096; k = k + 1) begin
                        dp_table[i][j][k] <= 32'd0;
                    end
                end
            end
            
            // Initialize input array
            for (i = 0; i < 12; i = i + 1) begin
                input_arr[i] <= 4'd0;
                sorted_arr[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PARSE;
                    end
                end
                
                PARSE: begin
                    // Parse input array
                    for (i = 0; i < 12; i = i + 1) begin
                        input_arr[i] <= data_in[i*4 +: 4];
                    end
                    
                    // Sort the array (bubble sort for simplicity)
                    reg [3:0] temp;
                    reg [3:0] arr_copy [0:11];
                    for (i = 0; i < 12; i = i + 1) begin
                        arr_copy[i] = input_arr[i];
                    end
                    
                    for (i = 0; i < 11; i = i + 1) begin
                        for (j = 0; j < 11 - i; j = j + 1) begin
                            if (arr_copy[j] > arr_copy[j + 1]) begin
                                temp = arr_copy[j];
                                arr_copy[j] = arr_copy[j + 1];
                                arr_copy[j + 1] = temp;
                            end
                        end
                    end
                    
                    for (i = 0; i < 12; i = i + 1) begin
                        sorted_arr[i] = arr_copy[i];
                    end
                    
                    state <= COMPUTE;
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Base case: first position
                    if (pos_idx == 4'd0) begin
                        for (i = 0; i < 12; i = i + 1) begin
                            dp_table[0][i][1 << i] <= 32'd1;
                        end
                        pos_idx <= 4'd1;
                    end
                    
                    // DP computation
                    else if (pos_idx < N) begin
                        for (i = 0; i < 12; i = i + 1) begin
                            if (!(mask[i])) begin
                                for (j = 0; j < 12; j = j + 1) begin
                                    if (mask[j]) begin
                                        // Check if current element is not a local minimum
                                        reg is_sorted;
                                        is_sorted = 1'b0;
                                        
                                        // Check left neighbor
                                        if (j > 0 && mask[j - 1]) begin
                                            if (sorted_arr[i] >= sorted_arr[j - 1]) begin
                                                is_sorted = 1'b1;
                                            end
                                        end
                                        
                                        // Check right neighbor
                                        if (j < 11 && mask[j + 1]) begin
                                            if (sorted_arr[i] <= sorted_arr[j + 1]) begin
                                                is_sorted = 1'b1;
                                            end
                                        end
                                        
                                        if (!is_sorted) begin
                                            dp_table[pos_idx][i][mask | (1 << i)] <= 
                                                (dp_table[pos_idx][i][mask | (1 << i)] + 
                                                 dp_table[pos_idx - 1][j][mask]) % MOD;
                                        end
                                    end
                                end
                            end
                        end
                        
                        // Update mask and position
                        mask <= mask + 12'd1;
                        if (mask == 12'd4095) begin
                            mask <= 12'd0;
                            pos_idx <= pos_idx + 4'd1;
                        end
                    end
                    
                    // Sum up results
                    else begin
                        temp_result <= 32'd0;
                        for (i = 0; i < 12; i = i + 1) begin
                            temp_result <= (temp_result + dp_table[11][i][4095]) % MOD;
                        end
                        state <= FINISH;
                    end
                    
                    // Safety counter
                    if (cycle_count >= 8'd200) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= temp_result;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
endmodule