module make_impossible(
    input clk,
    input rst_n,
    input start,
    input [0:7] seq_0,
    input [0:7] seq_1,
    input [0:7] seq_2,
    input [0:7] seq_3,
    input [0:7] seq_4,
    input [0:7] seq_5,
    input [0:7] seq_6,
    input [0:7] seq_7,
    input [3:0] k,
    input signed [15:0] cost_0,
    input signed [15:0] cost_1,
    input signed [15:0] cost_2,
    input signed [15:0] cost_3,
    input signed [15:0] cost_4,
    input signed [15:0] cost_5,
    input signed [15:0] cost_6,
    input signed [15:0] cost_7,
    output reg signed [15:0] min_cost,
    output reg success,
    output reg done
);

    // State declarations
    localparam [2:0] S_IDLE = 3'd0;
    localparam [2:0] S_PREPARE = 3'd1;
    localparam [2:0] S_ENUMERATE = 3'd2;
    localparam [2:0] S_COMPUTE = 3'd3;
    localparam [2:0] S_CHECK = 3'd4;
    localparam [2:0] S_DONE = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] barry_counter;
    reg [7:0] i, j, l;
    reg [3:0] dp_table [0:8][0:8];
    reg [15:0] current_cost;
    reg [15:0] temp_min_cost;
    reg [7:0] temp_seq [0:7];
    reg found_valid;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100000;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            next_state <= S_IDLE;
            barry_counter <= 8'd0;
            i <= 8'd0;
            j <= 8'd0;
            l <= 8'd0;
            current_cost <= 16'd0;
            temp_min_cost <= 16'd0;
            found_valid <= 1'b0;
            cycle_count <= 8'd0;
            min_cost <= 16'd0;
            success <= 1'b0;
            done <= 1'b0;
            
            // Initialize DP table
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    dp_table[i][j] <= 4'd0;
                end
            end
            
            // Initialize temp sequence
            for (i = 0; i < 8; i = i + 1) begin
                temp_seq[i] <= 1'b0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= S_PREPARE;
                    end
                end
                
                S_PREPARE: begin
                    // Initialize for new computation
                    barry_counter <= 8'd0;
                    found_valid <= 1'b0;
                    temp_min_cost <= 16'd32767; // Initialize to max positive
                    next_state <= S_ENUMERATE;
                end
                
                S_ENUMERATE: begin
                    // Apply Barry's flips based on counter
                    for (i = 0; i < 8; i = i + 1) begin
                        if (barry_counter[i]) begin
                            temp_seq[i] <= ~seq_0[i]; // Assuming seq_0 is the base sequence
                        end else begin
                            temp_seq[i] <= seq_0[i];
                        end
                    end
                    
                    // Calculate current cost
                    current_cost <= 16'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (barry_counter[i]) begin
                            case (i)
                                0: current_cost <= current_cost + cost_0;
                                1: current_cost <= current_cost + cost_1;
                                2: current_cost <= current_cost + cost_2;
                                3: current_cost <= current_cost + cost_3;
                                4: current_cost <= current_cost + cost_4;
                                5: current_cost <= current_cost + cost_5;
                                6: current_cost <= current_cost + cost_6;
                                7: current_cost <= current_cost + cost_7;
                            endcase
                        end
                    end
                    
                    next_state <= S_COMPUTE;
                end
                
                S_COMPUTE: begin
                    // Compute DP table for Bruce's min flips
                    // Initialize DP table
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            dp_table[i][j] <= 4'd100; // Initialize to large value
                        end
                    end
                    
                    // Base case: empty sequence
                    dp_table[0][0] <= 4'd0;
                    
                    // Fill DP table
                    for (i = 1; i <= 8; i = i + 1) begin
                        for (j = 0; j <= 8; j = j + 1) begin
                            // Option 1: Don't flip current character
                            if (temp_seq[i-1] == 1'b0) begin
                                if (j > 0) begin
                                    dp_table[i][j] <= dp_table[i-1][j-1];
                                end
                            end else begin
                                dp_table[i][j] <= dp_table[i-1][j+1];
                            end
                            
                            // Option 2: Flip current character (if we have moves left)
                            if (j < k) begin
                                if (temp_seq[i-1] == 1'b0) begin
                                    if (j+1 <= 8) begin
                                        if (dp_table[i-1][j+1] + 1 < dp_table[i][j]) begin
                                            dp_table[i][j] <= dp_table[i-1][j+1] + 1;
                                        end
                                    end
                                end else begin
                                    if (j > 0) begin
                                        if (dp_table[i-1][j-1] + 1 < dp_table[i][j]) begin
                                            dp_table[i][j] <= dp_table[i-1][j-1] + 1;
                                        end
                                    end
                                end
                            end
                        end
                    end
                    
                    next_state <= S_CHECK;
                end
                
                S_CHECK: begin
                    // Check if Bruce can balance the sequence
                    if (dp_table[8][0] > k) begin
                        // Barry wins - update min cost
                        found_valid <= 1'b1;
                        if (current_cost < temp_min_cost) begin
                            temp_min_cost <= current_cost;
                        end
                    end
                    
                    // Move to next Barry subset
                    barry_counter <= barry_counter + 8'd1;
                    
                    if (barry_counter == 8'd255) begin
                        next_state <= S_DONE;
                    end else begin
                        next_state <= S_ENUMERATE;
                    end
                end
                
                S_DONE: begin
                    if (found_valid) begin
                        success <= 1'b1;
                        min_cost <= temp_min_cost;
                    end else begin
                        success <= 1'b0;
                        min_cost <= 16'd0;
                    end
                    done <= 1'b1;
                    next_state <= S_IDLE;
                end
                
                default: next_state <= S_IDLE;
            endcase
            
            // Cycle counter for safety
            if (cycle_count == MAX_CYCLES) begin
                next_state <= S_IDLE;
                done <= 1'b1;
            end else begin
                cycle_count <= cycle_count + 8'd1;
            end
        end
    end
endmodule