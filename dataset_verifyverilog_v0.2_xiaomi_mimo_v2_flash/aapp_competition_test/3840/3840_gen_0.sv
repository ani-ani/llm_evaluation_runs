module pirate_chest_solver (
    input clk,
    input rst_n,
    input start,
    input [4:0] n,  // Number of chests (1-15)
    input [15:0] coins [0:14],  // Coin counts for chests 1-15 (index 0=chest1)
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam VALIDATE = 3'b001;
    localparam PROCESS_LOOP = 3'b010;
    localparam CALCULATE_RESULT = 3'b011;
    localparam DONE = 3'b100;

    // Registers and wires
    reg [2:0] state;
    reg [4:0] i;  // Loop counter for chests (1 to n)
    reg [15:0] moves;
    reg [15:0] coins_reg [0:14];  // Local copy of coins to modify
    reg [15:0] temp_coins_i;
    reg [15:0] temp_coins_parent;
    reg [15:0] temp_coins_sibling;
    reg process_flag;  // Flag to trigger process logic

    // Integer for loop unrolling in comb block
    integer idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'h0000;
            done <= 1'b0;
            moves <= 16'h0000;
            i <= 5'd0;
            process_flag <= 1'b0;
            // Initialize coins_reg
            for (idx = 0; idx < 15; idx = idx + 1) begin
                coins_reg[idx] <= 16'h0000;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    process_flag <= 1'b0;
                    if (start) begin
                        // Load input coins into local register array
                        for (idx = 0; idx < 15; idx = idx + 1) begin
                            if (idx < n) begin
                                coins_reg[idx] <= coins[idx];
                            end else begin
                                coins_reg[idx] <= 16'h0000;
                            end
                        end
                        moves <= 16'h0000;
                        state <= VALIDATE;
                    end
                end

                VALIDATE: begin
                    // Validate input: if n==1 or n is even, return -1
                    if (n == 5'd1 || n[0] == 1'b0) begin // n even check on bit 0
                        result <= 16'hFFFF; // -1 in 16-bit 2's complement
                        state <= DONE;
                    end else begin
                        // Start processing from highest chest index down to 1
                        // n is max 15, so valid indices are 0 to 14 (chest 1 to 15)
                        i <= n;  // n is the number of chests, so last index is n (chest number n is index n-1, but we iterate on chest number i)
                        // Wait one cycle to stabilize loop
                        state <= PROCESS_LOOP;
                    end
                end

                PROCESS_LOOP: begin
                    // Iterate from chest number n down to 1
                    // i holds the chest number (1-based)
                    if (i > 5'd1) begin
                        // Current chest index is i-1
                        if (coins_reg[i-1] > 16'h0000) begin
                            // Add coins to moves
                            moves <= moves + coins_reg[i-1];
                            
                            // Determine parent: parent = i / 2
                            // Parent index = (i/2) - 1
                            // Determine sibling: if i is odd, sibling is i-1
                            
                            // We need to perform updates based on current values, 
                            // but in sequential logic we update registers directly.
                            // However, we must be careful about multiple updates to the same register.
                            // We will use temporary registers loaded in previous cycle or combinational logic.
                            
                            // Since this is sequential block, we update coins_reg entries.
                            // We need to subtract from parent (and sibling if odd).
                            // Note: Since we iterate downwards, we only modify indices < i-1.
                            
                            if (i[0]) begin // i is odd (e.g., 3, 5, 7...)
                                // Sibling is i-1 (index i-2)
                                // Parent is i/2 (index i/2 - 1)
                                
                                // Update Sibling (i-1)
                                if (coins_reg[i-2] >= coins_reg[i-1]) begin
                                    coins_reg[i-2] <= coins_reg[i-2] - coins_reg[i-1];
                                end else begin
                                    coins_reg[i-2] <= 16'h0000;
                                end
                                
                                // Update Parent ((i-1)/2)
                                // Parent index = (i >> 1) - 1
                                if (coins_reg[(i >> 1) - 1] >= coins_reg[i-1]) begin
                                    coins_reg[(i >> 1) - 1] <= coins_reg[(i >> 1) - 1] - coins_reg[i-1];
                                end else begin
                                    coins_reg[(i >> 1) - 1] <= 16'h0000;
                                end
                                
                            end else begin // i is even (e.g., 2, 4, 6...)
                                // Only update Parent
                                // Parent index = (i >> 1) - 1
                                if (coins_reg[(i >> 1) - 1] >= coins_reg[i-1]) begin
                                    coins_reg[(i >> 1) - 1] <= coins_reg[(i >> 1) - 1] - coins_reg[i-1];
                                end else begin
                                    coins_reg[(i >> 1) - 1] <= 16'h0000;
                                end
                            end
                            
                            // Set current chest coins to 0
                            coins_reg[i-1] <= 16'h0000;
                        end
                        
                        // Decrement i
                        i <= i - 1'b1;
                    end else begin
                        // i == 1, loop finished
                        state <= CALCULATE_RESULT;
                    end
                end

                CALCULATE_RESULT: begin
                    // Final check on chest 1 (index 0)
                    // If chest 1 has coins, it's impossible (return -1)
                    if (coins_reg[0] > 16'h0000) begin
                        result <= 16'hFFFF; // -1
                    end else begin
                        result <= moves;
                    end
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
