module RookieBunny(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] s1,
    input wire [3:0] s2,
    input wire [3:0] t_i,
    output reg [3:0] result,
    output reg done,
    output reg load_ready
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] FINISH    = 3'd3;

    reg [2:0] state, next_state;

    // Customer counter
    reg [3:0] customer_idx;

    // Remaining time registers for DP state
    reg [3:0] rem1_reg [0:15];
    reg [3:0] rem2_reg [0:15];
    reg [3:0] rem1_next [0:15];
    reg [3:0] rem2_next [0:15];

    // Reachable set size and valid flags
    reg [3:0] reachable_size;
    reg [3:0] reachable_size_next;
    reg [0:15] valid [0:15];
    reg [0:15] valid_next [0:15];

    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Initialize all registers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            customer_idx <= 4'd0;
            result <= 4'd0;
            done <= 1'b0;
            load_ready <= 1'b0;
            cycle_count <= 8'd0;
            reachable_size <= 4'd0;
            reachable_size_next <= 4'd0;
            
            // Initialize DP state arrays
            for (i = 0; i < 16; i = i + 1) begin
                rem1_reg[i] <= 4'd0;
                rem2_reg[i] <= 4'd0;
                rem1_next[i] <= 4'd0;
                rem2_next[i] <= 4'd0;
                valid[i] <= 1'b0;
                valid_next[i] <= 1'b0;
            end
            
            // Initial state: (s1, s2) is reachable
            rem1_reg[0] <= s1;
            rem2_reg[0] <= s2;
            valid[0] <= 1'b1;
            reachable_size <= 4'd1;
        end else begin
            state <= next_state;
            
            // Update DP state arrays
            for (i = 0; i < 16; i = i + 1) begin
                rem1_reg[i] <= rem1_next[i];
                rem2_reg[i] <= rem2_next[i];
                valid[i] <= valid_next[i];
            end
            reachable_size <= reachable_size_next;
            
            // Update customer index
            if (next_state == LOAD && state == LOAD) begin
                customer_idx <= customer_idx + 4'd1;
            end
            
            // Update cycle count
            if (state != IDLE && state != FINISH) begin
                cycle_count <= cycle_count + 8'd1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        load_ready = 1'b0;
        done = 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                    load_ready = 1'b1;
                    cycle_count = 8'd0;
                end
            end
            
            LOAD: begin
                if (customer_idx < n - 4'd1) begin
                    next_state = LOAD;
                    load_ready = 1'b1;
                end else begin
                    next_state = COMPUTE;
                end
            end
            
            COMPUTE: begin
                // Check if we've processed all customers
                if (customer_idx == n) begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
                done = 1'b1;
            end
            
            default: next_state = IDLE;
        endcase
        
        // Timeout protection
        if (cycle_count >= MAX_CYCLES) begin
            next_state = FINISH;
        end
    end

    // DP state update logic
    always @(*) begin
        reachable_size_next = 4'd0;
        
        // Initialize next state arrays
        for (i = 0; i < 16; i = i + 1) begin
            rem1_next[i] = 4'd0;
            rem2_next[i] = 4'd0;
            valid_next[i] = 1'b0;
        end
        
        // Process current customer time requirement
        if (state == COMPUTE && customer_idx < n) begin
            reg [3:0] current_t = (state == LOAD) ? t_i : rem1_reg[0];
            reg [3:0] new_idx = 4'd0;
            
            // Process each reachable state
            for (i = 0; i < 16; i = i + 1) begin
                if (valid[i]) begin
                    // Option 1: Assign to counter 1 if possible
                    if (rem1_reg[i] >= current_t) begin
                        rem1_next[new_idx] = rem1_reg[i] - current_t;
                        rem2_next[new_idx] = rem2_reg[i];
                        valid_next[new_idx] = 1'b1;
                        new_idx = new_idx + 4'd1;
                    end
                    
                    // Option 2: Assign to counter 2 if possible
                    if (rem2_reg[i] >= current_t) begin
                        rem1_next[new_idx] = rem1_reg[i];
                        rem2_next[new_idx] = rem2_reg[i] - current_t;
                        valid_next[new_idx] = 1'b1;
                        new_idx = new_idx + 4'd1;
                    end
                end
            end
            
            reachable_size_next = new_idx;
        end
    end

    // Result calculation
    always @(*) begin
        if (state == FINISH) begin
            // Count how many customers could be served
            reg [3:0] count = 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                if (valid[i]) begin
                    count = count + 4'd1;
                end
            end
            result = count;
        end
    end

endmodule