module knapsack_multi_capacity (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] item_size,
    input wire [15:0] item_value,
    input wire item_valid,
    input wire item_done,
    output wire [1023:0] dp_out,
    output wire done,
    output wire busy
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] WAIT_ITEM = 3'd1;
    localparam [2:0] COMPUTE_DP = 3'd2;
    localparam [2:0] UPDATE_BUFFER = 3'd3;
    localparam [2:0] FINALIZE = 3'd4;
    localparam [2:0] OUTPUT = 3'd5;

    // Internal signals
    reg [2:0] state, next_state;
    reg [5:0] capacity_counter;
    reg [5:0] item_counter;
    reg [15:0] current_dp [0:63];
    reg [15:0] next_dp [0:63];
    reg [15:0] temp_dp [0:63];
    reg done_reg;
    reg busy_reg;
    reg [1023:0] dp_out_reg;
    reg item_processed;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            capacity_counter <= 6'd0;
            item_counter <= 6'd0;
            done_reg <= 1'b0;
            busy_reg <= 1'b0;
            item_processed <= 1'b0;
            
            // Initialize DP arrays
            integer i;
            for (i = 0; i < 64; i = i + 1) begin
                current_dp[i] <= 16'd0;
                next_dp[i] <= 16'd0;
                temp_dp[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            
            // Update counters based on current state
            case (state)
                COMPUTE_DP: begin
                    if (capacity_counter < 6'd64) begin
                        capacity_counter <= capacity_counter + 6'd1;
                    end
                end
                
                UPDATE_BUFFER: begin
                    capacity_counter <= 6'd0;
                    if (item_processed) begin
                        item_counter <= item_counter + 6'd1;
                        item_processed <= 1'b0;
                    end
                end
                
                FINALIZE: begin
                    if (capacity_counter < 6'd64) begin
                        capacity_counter <= capacity_counter + 6'd1;
                    end
                end
                
                default: ;
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = WAIT_ITEM;
                end
            end
            
            WAIT_ITEM: begin
                if (item_valid) begin
                    next_state = COMPUTE_DP;
                end else if (item_done) begin
                    next_state = FINALIZE;
                end
            end
            
            COMPUTE_DP: begin
                if (capacity_counter == 6'd64) begin
                    next_state = UPDATE_BUFFER;
                end
            end
            
            UPDATE_BUFFER: begin
                if (item_done) begin
                    next_state = FINALIZE;
                end else begin
                    next_state = WAIT_ITEM;
                end
            end
            
            FINALIZE: begin
                if (capacity_counter == 6'd64) begin
                    next_state = OUTPUT;
                end
            end
            
            OUTPUT: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // DP computation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized in main reset block
        end else begin
            case (state)
                COMPUTE_DP: begin
                    integer cap = capacity_counter;
                    if (cap > 0) begin
                        cap = cap - 1;
                        if (cap >= item_size) begin
                            // Compute max between current and new value
                            if (current_dp[cap] > current_dp[cap - item_size] + item_value) begin
                                temp_dp[cap] <= current_dp[cap];
                            end else begin
                                temp_dp[cap] <= current_dp[cap - item_size] + item_value;
                            end
                        end else begin
                            temp_dp[cap] <= current_dp[cap];
                        end
                    end
                end
                
                UPDATE_BUFFER: begin
                    if (capacity_counter == 6'd0) begin
                        // Copy temp_dp to next_dp
                        integer i;
                        for (i = 0; i < 64; i = i + 1) begin
                            next_dp[i] <= temp_dp[i];
                        end
                        item_processed <= 1'b1;
                    end
                end
                
                FINALIZE: begin
                    if (capacity_counter < 6'd64) begin
                        integer cap = capacity_counter;
                        current_dp[cap] <= next_dp[cap];
                    end
                end
                
                default: ;
            endcase
        end
    end

    // Output packing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dp_out_reg <= 1024'd0;
        end else begin
            if (state == OUTPUT) begin
                // Pack current_dp into dp_out_reg
                integer i;
                for (i = 0; i < 64; i = i + 1) begin
                    dp_out_reg[(i+1)*16-1 : i*16] <= current_dp[i];
                end
            end
        end
    end

    // Done and busy signals
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done_reg <= 1'b0;
            busy_reg <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done_reg <= 1'b0;
                    busy_reg <= 1'b0;
                end
                
                WAIT_ITEM: begin
                    done_reg <= 1'b0;
                    busy_reg <= 1'b1;
                end
                
                COMPUTE_DP: begin
                    done_reg <= 1'b0;
                    busy_reg <= 1'b1;
                end
                
                UPDATE_BUFFER: begin
                    done_reg <= 1'b0;
                    busy_reg <= 1'b1;
                end
                
                FINALIZE: begin
                    done_reg <= 1'b0;
                    busy_reg <= 1'b1;
                end
                
                OUTPUT: begin
                    done_reg <= 1'b1;
                    busy_reg <= 1'b0;
                end
                
                default: begin
                    done_reg <= 1'b0;
                    busy_reg <= 1'b0;
                end
            endcase
        end
    end

    // Output assignments
    assign dp_out = dp_out_reg;
    assign done = done_reg;
    assign busy = busy_reg;

endmodule