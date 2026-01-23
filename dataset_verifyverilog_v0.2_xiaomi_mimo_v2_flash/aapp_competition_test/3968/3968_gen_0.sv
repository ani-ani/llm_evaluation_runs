module virus_spread (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] init_infected,
    input wire [3:0] D,
    input wire [7:0][3:0] p_start_t,
    input wire [7:0][3:0] p_end_t,
    output reg [7:0] infected_status,
    output reg done
);

    // --- Parameters for States ---
    localparam IDLE = 2'b00;
    localparam SIMULATING = 2'b01;
    localparam DONE = 2'b10;

    // --- Registers for State Machine ---
    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] days_count;
    reg [3:0] next_days_count;
    reg [7:0] current_infected;
    reg [7:0] next_current_infected;
    reg [7:0] next_infected_status;
    reg next_done;

    // --- Combinational Logic for Time Masks ---
    // time_mask[i][t] is 1 if person i is present at time t
    wire [15:0] time_mask [7:0];
    
    genvar i, t;
    generate
        for (i = 0; i < 8; i = i + 1) begin : gen_time_masks
            for (t = 0; t < 16; t = t + 1) begin : gen_mask_bits
                // Check if t is between start and end (inclusive)
                assign time_mask[i][t] = (p_start_t[i] <= t && t <= p_end_t[i]);
            end
        end
    endgenerate

    // --- Combinational Logic for Contact Graph ---
    // contact[i][j] is 1 if person i and j overlap in time
    wire [7:0] contact [7:0];

    generate
        for (i = 0; i < 8; i = i + 1) begin : gen_contact_rows
            for (int j = 0; j < 8; j = j + 1) begin : gen_contact_cols
                // Check for any bit overlap between time masks
                assign contact[i][j] = |(time_mask[i] & time_mask[j]);
            end
        end
    endgenerate

    // --- Combinational Logic for New Infections ---
    // Logic derived from requirements: 
    // "If contact[j][k] is 1 and current_infected[k] is 0 -> new_infections[k] = 1"
    // where j iterates over currently infected people.
    reg [7:0] new_infections;
    integer k_idx, j_idx;

    always @(*) begin
        new_infections = 8'b0;
        // Iterate over all potential 'receivers' k
        for (k_idx = 0; k_idx < 8; k_idx = k_idx + 1) begin
            // Condition: Person k is currently uninfected
            if (!current_infected[k_idx]) begin
                // Check if ANY currently infected person j has contact with k
                for (j_idx = 0; j_idx < 8; j_idx = j_idx + 1) begin
                    if (current_infected[j_idx] && contact[j_idx][k_idx]) begin
                        new_infections[k_idx] = 1'b1;
                        break; // Once marked infected by one person, no need to check others for k
                    end
                end
            end
        end
    end

    // --- Next State Logic (Combinational) ---
    always @(*) begin
        // Default assignments to prevent latches
        next_state = state;
        next_days_count = days_count;
        next_current_infected = current_infected;
        next_infected_status = infected_status;
        next_done = done;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SIMULATING;
                    next_days_count = 0;
                    next_current_infected = init_infected;
                    next_done = 1'b0;
                    next_infected_status = 8'b0; // Initialize output
                end else begin
                    next_done = 1'b1; // Keep done high in IDLE unless starting
                end
            end

            SIMULATING: begin
                if (days_count >= D) begin
                    // Simulation complete for D days
                    next_state = DONE;
                    next_infected_status = current_infected; // Latch the result
                    next_done = 1'b1;
                end else begin
                    // Calculate next day's infection status
                    // Update current_infected immediately for the next cycle
                    next_current_infected = current_infected | new_infections;
                    next_days_count = days_count + 1;
                end
            end

            DONE: begin
                // Stay in DONE state
                // If start is pressed again (implicit reset), handled by priority in IDLE or explicit reset
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // --- Sequential Logic (Sequential Block) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            days_count <= 4'b0;
            current_infected <= 8'b0;
            infected_status <= 8'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            days_count <= next_days_count;
            current_infected <= next_current_infected;
            infected_status <= next_infected_status;
            done <= next_done;
        end
    end

endmodule