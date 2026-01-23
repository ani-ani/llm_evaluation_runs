module max_points_game (
    input clk,
    input rst_n,
    input start,
    input [7:0] sequence_in,
    input load_valid,
    output reg [15:0] max_score,
    output reg done
);

    // Parameters for State Encoding
    localparam IDLE = 2'b00;
    localparam LOAD = 2'b01;
    localparam PROCESSING = 2'b10;
    localparam DONE_STATE = 2'b11;

    // Registers for State Machine
    reg [1:0] current_state;
    reg [1:0] next_state;

    // Counter for loading (0 to 15)
    reg [3:0] load_counter;
    wire load_complete;

    // Counter for processing (0 to 255)
    reg [7:0] proc_counter;

    // LUT for counts (256 entries of 4 bits, assuming max count is 16)
    reg [3:0] count_lut [0:255];
    wire [3:0] current_count;

    // DP Registers (history)
    reg [15:0] dp_i_minus_2; // dp[i-2]
    reg [15:0] dp_i_minus_1; // dp[i-1]
    reg [15:0] dp_i;         // dp[i]

    // Computation wires
    reg [15:0] current_points;
    reg [15:0] candidate;
    reg [15:0] next_dp;

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end
            LOAD: begin
                if (load_complete)
                    next_state = PROCESSING;
                else
                    next_state = LOAD;
            end
            PROCESSING: begin
                if (proc_counter == 8'd255) // Processing complete when i reaches 255
                    next_state = DONE_STATE;
                else
                    next_state = PROCESSING;
            end
            DONE_STATE: begin
                // Stay in DONE until reset or new start
                if (start)
                    next_state = LOAD;
                else
                    next_state = DONE_STATE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Load Counter Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_counter <= 4'd0;
        end else if (current_state == LOAD) begin
            if (load_valid && !load_complete) begin
                load_counter <= load_counter + 1'b1;
            end
        end else begin
            load_counter <= 4'd0;
        end
    end

    assign load_complete = (load_counter == 4'd15) && load_valid;

    // LUT Write Logic
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize LUT to 0
            for (i = 0; i < 256; i = i + 1) begin
                count_lut[i] <= 4'b0;
            end
        end else if (current_state == LOAD && load_valid) begin
            // Increment count for the current sequence input
            count_lut[sequence_in] <= count_lut[sequence_in] + 1'b1;
        end
    end

    // LUT Read Logic (Combinational)
    assign current_count = count_lut[proc_counter];

    // Processing Counter Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            proc_counter <= 8'd0;
        end else if (current_state == PROCESSING) begin
            proc_counter <= proc_counter + 1'b1;
        end else begin
            proc_counter <= 8'd0;
        end
    end

    // DP Calculation Logic (Combinational)
    always @(*) begin
        // current_points = i * count[i]
        // proc_counter is 'i'. Ensure multiplication fits in 16 bits (255 * 16 = 4080)
        current_points = proc_counter * current_count;
        
        // candidate = dp[i-2] + current_points
        candidate = dp_i_minus_2 + current_points;
        
        // next_dp = max(dp[i-1], candidate)
        if (dp_i_minus_1 > candidate) begin
            next_dp = dp_i_minus_1;
        end else begin
            next_dp = candidate;
        end
    end

    // DP Register Updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dp_i_minus_2 <= 16'b0;
            dp_i_minus_1 <= 16'b0;
            dp_i <= 16'b0;
        end else if (current_state == PROCESSING) begin
            // Shift history: i-1 becomes i-2, current computed value becomes i-1
            // Note: Logic is sequential, so we update based on the value calculated for this cycle
            dp_i_minus_2 <= dp_i_minus_1;
            dp_i_minus_1 <= dp_i;
            dp_i <= next_dp;
        end else if (current_state == LOAD) begin
            // Reset DP registers when entering load/reset
            dp_i_minus_2 <= 16'b0;
            dp_i_minus_1 <= 16'b0;
            dp_i <= 16'b0;
        end
    end

    // Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_score <= 16'b0;
            done <= 1'b0;
        end else if (current_state == DONE_STATE) begin
            max_score <= dp_i;
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule
