module max_bling_calculator (
    input clk,
    input rst_n,
    input start,
    input [7:0] d_in,
    input [7:0] b_in,
    input [7:0] f_in,
    input [7:0] t0_in,
    input [7:0] t1_in,
    input [7:0] t2_in,
    output reg [15:0] result,
    output reg done
);

    // State registers
    reg [7:0] current_days;
    reg [15:0] current_bling;
    reg [7:0] current_fruits;
    reg [7:0] trees_0, trees_1, trees_2;
    reg [2:0] state;

    // State constants
    localparam IDLE       = 3'b000;
    localparam SIMULATE   = 3'b001;
    localparam DONE_STATE = 3'b010;

    // Waveform dump
    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, max_bling_calculator);
    end

    // ============================================
    // REMOVED THE BUGGY always @(*) BLOCK!
    // ============================================

    // Single synchronous always block with async reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            current_days   <= 8'd0;
            current_bling  <= 16'd0;
            current_fruits <= 8'd0;
            trees_0        <= 8'd0;
            trees_1        <= 8'd0;
            trees_2        <= 8'd0;
            state          <= IDLE;
            done           <= 1'b0;
            result         <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_days   <= d_in;
                        current_bling  <= {8'b0, b_in};  // Zero-extend to 16 bits
                        current_fruits <= f_in;
                        trees_0        <= t0_in;
                        trees_1        <= t1_in;
                        trees_2        <= t2_in;
                        state          <= SIMULATE;
                    end
                end

                SIMULATE: begin
                    if (current_days == 8'd0) begin
                        // No more days - finish
                        state  <= DONE_STATE;
                        done   <= 1'b1;
                        result <= current_bling;
                    end else begin
                        // Process one day
                        reg [15:0] new_bling;
                        reg [7:0]  new_fruits;
                        reg [7:0]  new_t0, new_t1, new_t2;
                        reg [7:0]  plant_amt;
                        reg [7:0]  days_left;

                        // Initialize intermediate variables
                        days_left  = current_days;
                        plant_amt  = 8'd0;
                        new_bling  = current_bling;
                        new_fruits = current_fruits;

                        // Step 1: Harvest (add 3 fruits per mature tree)
                        new_fruits = current_fruits + (trees_0 * 8'd3);

                        // Step 2: Plant if days >= 3
                        if (days_left >= 8'd3) begin
                            plant_amt  = new_fruits;
                            new_fruits = 8'd0;
                        end else begin
                            plant_amt = 8'd0;
                        end

                        // Step 3: Buy exotic if enough bling
                        if (current_bling >= 16'd400) begin
                            if (days_left < 8'd3) begin
                                // Sell exotic for profit
                                new_bling = current_bling + 16'd100;
                            end else begin
                                // Buy exotic
                                new_bling = current_bling - 16'd400;
                            end
                        end

                        // Step 4: Sell fruits if days < 3
                        if (days_left < 8'd3) begin
                            new_bling  = new_bling + (new_fruits * 16'd100);
                            new_fruits = 8'd0;
                        end

                        // Step 5: Age trees (shift pipeline)
                        new_t0 = trees_1;
                        new_t1 = trees_2;
                        new_t2 = plant_amt;

                        // Step 6: Decrement days
                        days_left = current_days - 8'd1;

                        // Update state
                        if (days_left == 8'd0) begin
                            state  <= DONE_STATE;
                            done   <= 1'b1;
                            result <= new_bling;
                        end else begin
                            current_fruits <= new_fruits;
                            current_bling  <= new_bling;
                            trees_0        <= new_t0;
                            trees_1        <= new_t1;
                            trees_2        <= new_t2;
                            current_days   <= days_left;
                            // Stay in SIMULATE state
                        end
                    end
                end

                DONE_STATE: begin
                    // Stay in DONE until reset
                    // done and result remain valid
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule