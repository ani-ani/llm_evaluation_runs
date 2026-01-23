module widget_profit_maximizer (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_producers,
    input [2:0] num_consumers,
    input [7:0] producer_prices [0:7],
    input [7:0] producer_dates [0:7],
    input [7:0] consumer_prices [0:7],
    input [7:0] consumer_dates [0:7],
    output reg [15:0] max_profit,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam CALCULATING = 2'b01;
    localparam DONE = 2'b10;

    // Registers for state and counters
    reg [1:0] state;
    reg [2:0] p_idx; // producer index (0-7)
    reg [2:0] c_idx; // consumer index (0-7)
    
    // Intermediate calculation registers
    reg [7:0] current_p_price;
    reg [7:0] current_p_date;
    reg [7:0] current_c_price;
    reg [7:0] current_c_date;
    
    // Pipeline registers for calculation stages
    // Stage 1: Read values and subtract prices/dates
    reg signed [8:0] profit_per_day_s1; // signed for negative check
    reg signed [8:0] days_s1;           // signed for negative check
    reg [15:0] total_profit_s1;         // stored to avoid overflow issues
    
    // Stage 2: Multiplication result
    reg [15:0] total_profit_s2;
    reg valid_pair_s2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_profit <= 16'b0;
            done <= 1'b0;
            p_idx <= 3'b0;
            c_idx <= 3'b0;
            // Reset pipeline registers
            profit_per_day_s1 <= 9'sd0;
            days_s1 <= 9'sd0;
            total_profit_s1 <= 16'b0;
            total_profit_s2 <= 16'b0;
            valid_pair_s2 <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CALCULATING;
                        max_profit <= 16'b0;
                        p_idx <= 3'b0;
                        c_idx <= 3'b0;
                    end
                end

                CALCULATING: begin
                    // --- Pipeline Stage 1: Read and Subtract ---
                    // We read inputs based on current indices immediately when in CALCULATING
                    // Note: This combinational read depends on the previous cycle's index update
                    // or the initial state entry. To make it synchronous, we align reads with
                    // the register updates at the end of the cycle.
                    
                    // Reading current pair data (addressed by current p_idx and c_idx)
                    current_p_price <= producer_prices[p_idx];
                    current_p_date  <= producer_dates[p_idx];
                    current_c_price <= consumer_prices[c_idx];
                    current_c_date  <= consumer_dates[c_idx];
                    
                    // --- Pipeline Stage 2: Check Validity and Calculate Total ---
                    // We use the values loaded in the previous clock cycle (stored in current_* registers)
                    // However, to keep it strictly 1 cycle per pair logic, we often structure pipeline
                    // as: Read(Stage 1) -> Process(Stage 2). 
                    // Here, we process the values loaded in the PREVIOUS cycle.
                    
                    // Calculate differences
                    profit_per_day_s1 <= $signed({1'b0, current_c_price}) - $signed({1'b0, current_p_price});
                    days_s1 <= $signed({1'b0, current_c_date}) - $signed({1'b0, current_p_date});
                    
                    // --- Pipeline Stage 3: Multiply and Accumulate ---
                    // Process results from Stage 1 pipeline registers
                    if (profit_per_day_s1 > 0 && days_s1 > 0) begin
                        valid_pair_s2 <= 1'b1;
                        total_profit_s2 <= profit_per_day_s1 * days_s1;
                    end else begin
                        valid_pair_s2 <= 1'b0;
                        total_profit_s2 <= 16'b0;
                    end
                    
                    // --- Pipeline Stage 4: Max Update and Index Control ---
                    // Update max profit if valid
                    if (valid_pair_s2) begin
                        if (total_profit_s2 > max_profit) begin
                            max_profit <= total_profit_s2;
                        end
                    end
                    
                    // Increment indices
                    if (c_idx == num_consumers - 1) begin
                        c_idx <= 3'b0;
                        if (p_idx == num_producers - 1) begin
                            // All pairs processed
                            state <= DONE;
                        end else begin
                            p_idx <= p_idx + 1'b1;
                        end
                    end else begin
                        c_idx <= c_idx + 1'b1;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (start) begin
                        // Restart if start is pressed again while done
                        state <= CALCULATING;
                        done <= 1'b0;
                        max_profit <= 16'b0;
                        p_idx <= 3'b0;
                        c_idx <= 3'b0;
                    end
                end
            endcase
        end
    end

endmodule
