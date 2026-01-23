module spell_optimizer (
    input clk,
    input rst_n,
    input start,
    input [7:0] step_types,
    output reg [2:0] max_power,
    output reg [7:0] best_mask,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam ITERATING = 2'b01;
    localparam DONE = 2'b10;

    // Registers for state machine
    reg [1:0] state;
    reg [1:0] next_state;

    // Registers for iteration logic
    reg [7:0] combination_cnt;
    reg [7:0] next_combination_cnt;
    reg [2:0] current_power;
    reg [2:0] next_current_power;
    reg [2:0] current_max_power;
    reg [2:0] next_current_max_power;
    reg [7:0] current_best_mask;
    reg [7:0] next_current_best_mask;
    reg [3:0] step_idx;
    reg [3:0] next_step_idx;

    // Registers for output buffering
    reg next_done;
    reg [2:0] next_max_power;
    reg [7:0] next_best_mask;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            combination_cnt <= 8'h00;
            current_power <= 3'b000;
            current_max_power <= 3'b000;
            current_best_mask <= 8'h00;
            step_idx <= 4'd0;
            done <= 1'b0;
            max_power <= 3'b000;
            best_mask <= 8'h00;
        end else begin
            state <= next_state;
            combination_cnt <= next_combination_cnt;
            current_power <= next_current_power;
            current_max_power <= next_current_max_power;
            current_best_mask <= next_current_best_mask;
            step_idx <= next_step_idx;
            done <= next_done;
            max_power <= next_max_power;
            best_mask <= next_best_mask;
        end
    end

    // Combinational logic
    always @(*) begin
        // Default assignments to prevent latches
        next_state = state;
        next_combination_cnt = combination_cnt;
        next_current_power = current_power;
        next_current_max_power = current_max_power;
        next_current_best_mask = current_best_mask;
        next_step_idx = step_idx;
        next_done = done;
        next_max_power = max_power;
        next_best_mask = best_mask;

        case (state)
            IDLE: begin
                next_done = 1'b0;
                if (start) begin
                    next_state = ITERATING;
                    next_combination_cnt = 8'h00;
                    next_current_max_power = 3'b000;
                    next_current_best_mask = 8'h00;
                    next_step_idx = 4'd0;
                    next_current_power = 3'b001; // Start with power = 1
                end
            end

            ITERATING: begin
                // Simulation logic: 8 steps per combination
                // Optimization: Unrolled simulation fits in 1 cycle logic for small M=8
                // We calculate the final power for the current 'combination_cnt' in this cycle
                
                // --- Power Simulation for current combination_cnt ---
                // This simulates the 8 steps for the current combination
                begin : simulation
                    reg [2:0] sim_power;
                    sim_power = 3'b001;
                    
                    // Step 0
                    if (combination_cnt[0]) begin
                        if (step_types[0]) sim_power = sim_power << 1;
                        else sim_power = sim_power + 1;
                    end
                    sim_power = sim_power & 3'b111;
                    
                    // Step 1
                    if (combination_cnt[1]) begin
                        if (step_types[1]) sim_power = sim_power << 1;
                        else sim_power = sim_power + 1;
                    end
                    sim_power = sim_power & 3'b111;
                    
                    // Step 2
                    if (combination_cnt[2]) begin
                        if (step_types[2]) sim_power = sim_power << 1;
                        else sim_power = sim_power + 1;
                    end
                    sim_power = sim_power & 3'b111;
                    
                    // Step 3
                    if (combination_cnt[3]) begin
                        if (step_types[3]) sim_power = sim_power << 1;
                        else sim_power = sim_power + 1;
                    end
                    sim_power = sim_power & 3'b111;
                    
                    // Step 4
                    if (combination_cnt[4]) begin
                        if (step_types[4]) sim_power = sim_power << 1;
                        else sim_power = sim_power + 1;
                    end
                    sim_power = sim_power & 3'b111;
                    
                    // Step 5
                    if (combination_cnt[5]) begin
                        if (step_types[5]) sim_power = sim_power << 1;
                        else sim_power = sim_power + 1;
                    end
                    sim_power = sim_power & 3'b111;
                    
                    // Step 6
                    if (combination_cnt[6]) begin
                        if (step_types[6]) sim_power = sim_power << 1;
                        else sim_power = sim_power + 1;
                    end
                    sim_power = sim_power & 3'b111;
                    
                    // Step 7
                    if (combination_cnt[7]) begin
                        if (step_types[7]) sim_power = sim_power << 1;
                        else sim_power = sim_power + 1;
                    end
                    sim_power = sim_power & 3'b111;
                    
                    // Update Max Logic
                    if (sim_power > current_max_power) begin
                        next_current_max_power = sim_power;
                        next_current_best_mask = combination_cnt;
                    end else begin
                        next_current_max_power = current_max_power;
                        next_current_best_mask = current_best_mask;
                    end
                end

                // Counter increment
                if (combination_cnt == 8'hFF) begin
                    next_state = DONE;
                    // Latch outputs from the accumulated max values
                    next_max_power = next_current_max_power;
                    next_best_mask = next_current_best_mask;
                    next_done = 1'b1;
                    next_combination_cnt = combination_cnt; // keep value or reset logic later
                end else begin
                    next_combination_cnt = combination_cnt + 1;
                end
            end

            DONE: begin
                // Hold outputs done is high until reset or new start
                // If start comes, state transitions in IDLE logic
                // Here we ensure done remains high if not reset
                // But typically we want to hold done high until reset
                // If we want to allow restart without reset, we can check !start here
                next_done = 1'b1;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
