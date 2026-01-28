module BlingMaximizer(
    input clk,
    input rst_n,
    input start,
    input [4:0] d_in,
    input [15:0] b_in,
    input [7:0] f_in,
    input [7:0] t0_in,
    input [7:0] t1_in,
    input [7:0] t2_in,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] SIMULATE  = 3'd2;
    localparam [2:0] FINISH    = 3'd3;

    reg [2:0] state, next_state;

    // Internal state registers
    reg [15:0] current_bling;
    reg [7:0] current_fruits;
    reg [7:0] current_exotic;
    reg [7:0] current_t0, current_t1, current_t2;
    reg [7:0] current_et0, current_et1, current_et2;
    reg [4:0] days_remaining;

    // Cycle counter for simulation
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end else begin
                    next_state = IDLE;
                end
            end

            INIT: begin
                next_state = SIMULATE;
            end

            SIMULATE: begin
                if (days_remaining == 5'd0 || cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end else begin
                    next_state = SIMULATE;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Initialization
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_bling <= 16'd0;
            current_fruits <= 8'd0;
            current_exotic <= 8'd0;
            current_t0 <= 8'd0;
            current_t1 <= 8'd0;
            current_t2 <= 8'd0;
            current_et0 <= 8'd0;
            current_et1 <= 8'd0;
            current_et2 <= 8'd0;
            days_remaining <= 5'd0;
        end else begin
            if (state == INIT) begin
                current_bling <= b_in;
                current_fruits <= f_in;
                current_exotic <= 8'd0;
                current_t0 <= t0_in;
                current_t1 <= t1_in;
                current_t2 <= t2_in;
                current_et0 <= 8'd0;
                current_et1 <= 8'd0;
                current_et2 <= 8'd0;
                days_remaining <= d_in;
                cycle_count <= 8'd0;
            end
        end
    end

    // Simulation logic
    always @(posedge clk) begin
        if (state == SIMULATE) begin
            // Harvest phase
            current_bling <= current_bling + (current_t0 * 16'd100) + (current_et0 * 16'd500);
            current_fruits <= current_fruits + (current_t0 * 8'd3);
            current_exotic <= current_exotic + (current_et0 * 8'd3);

            // Update tree counters
            current_t0 <= current_t1;
            current_t1 <= current_t2;
            current_t2 <= 8'd0;
            current_et0 <= current_et1;
            current_et1 <= current_et2;
            current_et2 <= 8'd0;

            // Sell phase
            current_bling <= current_bling + (current_fruits * 16'd100) + (current_exotic * 16'd500);
            current_fruits <= 8'd0;
            current_exotic <= 8'd0;

            // Buy phase
            if (current_bling >= 16'd400) begin
                current_bling <= current_bling - 16'd400;
                current_exotic <= current_exotic + 8'd1;
            end

            // Plant phase
            if (days_remaining > 5'd3) begin
                // Plant exotic fruits first
                if (current_exotic > 8'd0) begin
                    current_et2 <= current_et2 + current_exotic;
                    current_exotic <= 8'd0;
                end
                // Plant standard fruits
                if (current_fruits > 8'd0) begin
                    current_t2 <= current_t2 + current_fruits;
                    current_fruits <= 8'd0;
                end
            end

            // Decrement days
            days_remaining <= days_remaining - 5'd1;
            cycle_count <= cycle_count + 8'd1;
        end
    end

    // Output logic
    always @(posedge clk) begin
        if (state == FINISH) begin
            result <= current_bling;
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule