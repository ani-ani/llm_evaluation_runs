module coin_change_max(
    input clk,
    input rst_n,
    input start,
    input [15:0] price,
    input [6:0] n1,
    input [6:0] n5,
    input [6:0] n10,
    input [6:0] n25,
    output reg [15:0] max_coins,
    output reg done,
    output reg impossible
);

    // Parameters
    parameter IDLE = 4'b0000;
    parameter INIT = 4'b0001;
    parameter COIN_1 = 4'b0010;
    parameter COIN_5 = 4'b0011;
    parameter COIN_10 = 4'b0100;
    parameter COIN_25 = 4'b0101;
    parameter VERIFY = 4'b0110;
    parameter DONE = 4'b0111;
    parameter IMPOSSIBLE = 4'b1000;

    // State and next state
    reg [3:0] state;
    reg [3:0] next_state;

    // DP RAM signals
    reg [9:0] dp_addr_a;
    reg [9:0] dp_addr_b;
    reg [15:0] dp_din_a;
    reg [15:0] dp_din_b;
    reg dp_we_a;
    reg dp_we_b;
    wire [15:0] dp_dout_a;
    wire [15:0] dp_dout_b;

    // RAM instantiation (simple dual-port for read-modify-write)
    reg [15:0] dp_mem [0:1023];
    
    // Read logic
    assign dp_dout_a = dp_mem[dp_addr_a];
    assign dp_dout_b = dp_mem[dp_addr_b];
    
    // Write logic
    always @(posedge clk) begin
        if (dp_we_a)
            dp_mem[dp_addr_a] <= dp_din_a;
        if (dp_we_b)
            dp_mem[dp_addr_b] <= dp_din_b;
    end

    // Control registers
    reg [15:0] price_reg;
    reg [6:0] coin_count [0:3]; // 0:1c, 1:5c, 2:10c, 3:25c
    reg [15:0] denom;
    reg [15:0] max_usage;
    
    // Iteration counters
    reg [9:0] amount_idx;  // current amount from price down to 0
    reg [6:0] usage_idx;   // current coin usage k
    reg [15:0] base_amount;
    reg [15:0] base_coins;
    
    // State tracking for DP read
    reg read_stage; // 0: read base state, 1: read target state
    reg [15:0] new_amount;
    reg [15:0] new_coins;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT;
                else
                    next_state = IDLE;
            end
            
            INIT: begin
                next_state = COIN_1;
            end
            
            COIN_1: begin
                if (price_reg == 0) next_state = VERIFY;
                else if (amount_idx == 0 && usage_idx > max_usage) 
                    next_state = COIN_5;
                else
                    next_state = COIN_1;
            end
            
            COIN_5: begin
                if (amount_idx == 0 && usage_idx > max_usage) 
                    next_state = COIN_10;
                else
                    next_state = COIN_5;
            end
            
            COIN_10: begin
                if (amount_idx == 0 && usage_idx > max_usage) 
                    next_state = COIN_25;
                else
                    next_state = COIN_10;
            end
            
            COIN_25: begin
                if (amount_idx == 0 && usage_idx > max_usage) 
                    next_state = VERIFY;
                else
                    next_state = COIN_25;
            end
            
            VERIFY: begin
                next_state = DONE;
            end
            
            DONE: begin
                if (!start) next_state = IDLE;
                else next_state = DONE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic for operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            impossible <= 0;
            max_coins <= 0;
            dp_we_a <= 0;
            dp_we_b <= 0;
            dp_addr_a <= 0;
            dp_addr_b <= 0;
            amount_idx <= 0;
            usage_idx <= 0;
            read_stage <= 0;
        end else begin
            dp_we_a <= 0;
            dp_we_b <= 0;
            
            case (state)
                IDLE: begin
                    done <= 0;
                    impossible <= 0;
                    if (start) begin
                        price_reg <= price;
                        coin_count[0] <= n1;
                        coin_count[1] <= n5;
                        coin_count[2] <= n10;
                        coin_count[3] <= n25;
                    end
                end

                INIT: begin
                    // Initialize DP table: dp[0] = 0, rest = invalid (max)
                    if (amount_idx <= price_reg && amount_idx < 1024) begin
                        dp_addr_a <= amount_idx;
                        dp_din_a <= (amount_idx == 0) ? 16'h0000 : 16'hFFFF;
                        dp_we_a <= 1;
                        amount_idx <= amount_idx + 1;
                    end else begin
                        amount_idx <= price_reg; // Start from top for processing
                        usage_idx <= 0;
                        read_stage <= 0;
                    end
                end

                COIN_1, COIN_5, COIN_10, COIN_25: begin
                    // DP update state machine
                    case (state)
                        COIN_1: begin denom <= 1; max_usage <= coin_count[0]; end
                        COIN_5: begin denom <= 5; max_usage <= coin_count[1]; end
                        COIN_10: begin denom <= 10; max_usage <= coin_count[2]; end
                        COIN_25: begin denom <= 25; max_usage <= coin_count[3]; end
                    endcase

                    if (usage_idx == 0) begin
                        // Initialize usage loop
                        usage_idx <= 1;
                        amount_idx <= price_reg;
                        read_stage <= 0;
                    end else if (read_stage == 0) begin
                        // Read base state at 'amount_idx'
                        if (amount_idx >= 0 && amount_idx <= price_reg && amount_idx < 1024) begin
                            dp_addr_a <= amount_idx;
                            base_amount <= amount_idx;
                            read_stage <= 1;
                        end else begin
                            // Move to next amount
                            if (amount_idx == 0) begin
                                // Done with this usage, increment usage
                                usage_idx <= usage_idx + 1;
                                amount_idx <= price_reg;
                                read_stage <= 0;
                            end else begin
                                amount_idx <= amount_idx - 1;
                                read_stage <= 0;
                            end
                        end
                    end else begin // read_stage == 1
                        // Check base state validity and calculate new state
                        base_coins <= dp_dout_a;
                        if (dp_dout_a != 16'hFFFF) begin
                            // Calculate new amount and coins
                            new_amount <= amount_idx + (usage_idx * denom);
                            new_coins <= dp_dout_a + usage_idx;
                            // We need to write to new_amount if valid
                            // But we need to read old value first for max check
                            if ((amount_idx + (usage_idx * denom)) <= price_reg && 
                                (amount_idx + (usage_idx * denom)) < 1024) begin
                                dp_addr_b <= amount_idx + (usage_idx * denom);
                                read_stage <= 2; // Wait for read of target
                            end else begin
                                read_stage <= 3; // Skip write
                            end
                        end else begin
                            // Base invalid, skip
                            read_stage <= 3;
                        end
                    end
                    
                    else if (read_stage == 2) begin
                        // Compare and write
                        if (dp_dout_b < new_coins && new_coins != 16'hFFFF) begin
                            dp_addr_b <= new_amount;
                            dp_din_b <= new_coins;
                            dp_we_b <= 1;
                        end
                        read_stage <= 3;
                    end
                    
                    else if (read_stage == 3) begin
                        // Move to next amount
                        if (amount_idx == 0) begin
                            // Done with this usage
                            if (usage_idx >= max_usage) begin
                                // Done with coin type (will transition in next_state logic)
                                usage_idx <= 0; // Reset for next coin
                            end else begin
                                usage_idx <= usage_idx + 1;
                                amount_idx <= price_reg;
                            end
                            read_stage <= 0;
                        end else begin
                            amount_idx <= amount_idx - 1;
                            read_stage <= 0;
                        end
                    end
                end

                VERIFY: begin
                    dp_addr_a <= price_reg;
                    // Check if solution exists
                    if (price_reg == 0) begin
                        max_coins <= 0;
                        impossible <= 0;
                    end
                end

                DONE: begin
                    if (price_reg == 0) begin
                        done <= 1;
                    end else if (dp_dout_a != 16'hFFFF && price_reg < 1024) begin
                        max_coins <= dp_dout_a;
                        impossible <= 0;
                        done <= 1;
                    end else begin
                        max_coins <= 16'hFFFF;
                        impossible <= 1;
                        done <= 1;
                    end
                end
            endcase
        end
    end

endmodule