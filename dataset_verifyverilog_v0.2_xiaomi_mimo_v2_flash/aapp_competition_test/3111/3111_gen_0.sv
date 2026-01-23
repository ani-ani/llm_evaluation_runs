module dial_game (
    input clk,
    input rst_n,
    input start,
    input [3:0] A,
    input [3:0] B,
    input load,
    input [2:0] load_addr,
    input [3:0] load_data,
    output reg [7:0] sum_out,
    output reg done
);

    // Parameters
    parameter N = 8;

    // Internal Registers
    reg [3:0] dials [0:N-1]; // 8 dials, 4 bits each
    reg [2:0] idx;            // Iterator index (0-7)
    reg [7:0] sum_acc;        // Accumulator for sum
    reg processing;           // Flag to indicate calculation is in progress

    // State definitions
    localparam IDLE = 2'b00;
    localparam SUMMING = 2'b01;
    localparam UPDATING = 2'b10;
    localparam DONE_STATE = 2'b11;

    reg [1:0] current_state, next_state;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = SUMMING;
                end else begin
                    next_state = IDLE;
                end
            end
            SUMMING: begin
                // Check if iteration is done: idx == B-1 (converted to 0-based) + 1 for next cycle logic
                // Actually, easier logic: if idx > B-1, done summing
                if (idx > (B - 1)) begin
                    next_state = UPDATING;
                end else begin
                    next_state = SUMMING;
                end
            end
            UPDATING: begin
                if (idx > (B - 1)) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = UPDATING;
                end
            end
            DONE_STATE: begin
                if (!start) begin // Wait for start to go low before returning to IDLE
                    next_state = IDLE;
                end else begin
                    next_state = DONE_STATE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset dials to 0 (optional, but good for clean start)
            // In a real scenario, might keep values or reset to 0.
            // Let's reset dials to 0 to be safe, or rely on external load.
            // Since there is a load input, we won't reset dials content here to allow
            // external initialization even before release of rst_n if needed, 
            // but standard practice is to reset internal state.
            // Let's reset internal processing logic.
            done <= 1'b0;
            sum_out <= 8'b0;
            idx <= 3'b0;
            sum_acc <= 8'b0;
            processing <= 1'b0;
            // We leave dials undefined or 0. To ensure defined behavior:
            // dials[0] <= 4'd0; ... (unrolled or loop)
            // Since we have load, we assume testbench loads values.
            // Let's explicitly reset dials to 0 for synthesis safety.
            dials[0] <= 4'd0; dials[1] <= 4'd0; dials[2] <= 4'd0; dials[3] <= 4'd0;
            dials[4] <= 4'd0; dials[5] <= 4'd0; dials[6] <= 4'd0; dials[7] <= 4'd0;
        end else begin
            // Handle Load Operation (Priority over state machine if active at same time)
            if (load) begin
                dials[load_addr] <= load_data;
            end

            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize for SUMMING
                        idx <= A - 1; // Convert 1-based to 0-based
                        sum_acc <= 8'b0;
                    end
                end

                SUMMING: begin
                    // Accumulate sum
                    // Add current dial value to accumulator
                    sum_acc <= sum_acc + dials[idx];
                    // Increment index
                    idx <= idx + 1'b1;
                    // Note: Logic relies on next_state check in combinational block
                end

                UPDATING: begin
                    // Update current dial: (val + 1) % 10
                    if (dials[idx] == 4'd9) begin
                        dials[idx] <= 4'd0;
                    end else begin
                        dials[idx] <= dials[idx] + 1'b1;
                    end
                    // Increment index
                    idx <= idx + 1'b1;
                end

                DONE_STATE: begin
                    // Latch the final sum to output
                    sum_out <= sum_acc;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
