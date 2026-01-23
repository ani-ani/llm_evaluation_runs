module HouseNumberCounter(
    input [3:0] house_number [0:15],
    input [15:0] range_L,
    input [15:0] range_R,
    output reg [31:0] count
);
    
    // Constants
    localparam MOD = 32'd1000000007;
    localparam MAX_DIGITS = 16;
    localparam MAX_DIFF = 16;
    
    // DP state: [position][tight][diff]
    reg [31:0] dp [0:MAX_DIGITS][0:1][-MAX_DIFF:MAX_DIFF];
    
    // Current number being processed
    reg [3:0] current_digit [0:MAX_DIGITS];
    reg [15:0] current_number;
    
    // State machine states
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE = 2'd2;
    reg [1:0] state;
    
    // Counters and flags
    reg [4:0] pos;
    reg tight;
    reg signed [4:0] diff;
    reg [31:0] temp_count;
    reg [31:0] total;
    
    // Initialize DP table
    integer i, j, k;
    always @(*) begin
        // Reset DP table
        for (i = 0; i < MAX_DIGITS; i = i + 1) begin
            for (j = 0; j < 2; j = j + 1) begin
                for (k = -MAX_DIFF; k <= MAX_DIFF; k = k + 1) begin
                    dp[i][j][k] = 32'd0;
                end
            end
        end
        
        // Base case: position 0, tight=0, diff=0
        dp[0][0][0] = 32'd1;
    end
    
    // Digit processing logic
    always @(*) begin
        if (state == PROCESS) begin
            // Extract current digit
            current_digit[pos] = house_number[pos];
            
            // Check if digit is valid (no 4)
            if (current_digit[pos] == 4'd4) begin
                // Invalid digit, skip this path
                temp_count = 32'd0;
            end else begin
                // Calculate new difference
                if (current_digit[pos] == 4'd6 || current_digit[pos] == 4'd8) begin
                    diff = diff + 5'd1;
                end else begin
                    diff = diff - 5'd1;
                end
                
                // Update DP state
                if (pos < MAX_DIGITS - 1) begin
                    dp[pos + 1][tight][diff] = (dp[pos + 1][tight][diff] + dp[pos][tight][diff - (current_digit[pos] == 4'd6 || current_digit[pos] == 4'd8 ? 5'd1 : 5'd-1)]) % MOD;
                end else begin
                    // Final position, check if diff is 0
                    if (diff == 5'd0) begin
                        temp_count = 32'd1;
                    end else begin
                        temp_count = 32'd0;
                    end
                end
            end
        end
    end
    
    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pos <= 5'd0;
            tight <= 1'b0;
            diff <= 5'd0;
            total <= 32'd0;
            count <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    // Initialize for new range
                    state <= PROCESS;
                    pos <= 5'd0;
                    tight <= 1'b1;
                    diff <= 5'd0;
                    total <= 32'd0;
                end
                
                PROCESS: begin
                    // Process current digit
                    if (pos < MAX_DIGITS) begin
                        // Update position
                        pos <= pos + 5'd1;
                        
                        // Update tight constraint
                        if (tight && current_number == range_R) begin
                            tight <= 1'b1;
                        end else begin
                            tight <= 1'b0;
                        end
                        
                        // Accumulate count
                        total <= (total + temp_count) % MOD;
                    end else begin
                        // Done processing all digits
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    // Output final count
                    count <= total;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Convert BCD array to number
    always @(*) begin
        current_number = 16'd0;
        for (i = 0; i < MAX_DIGITS; i = i + 1) begin
            current_number = current_number * 16'd10 + house_number[i];
        end
    end
    
endmodule