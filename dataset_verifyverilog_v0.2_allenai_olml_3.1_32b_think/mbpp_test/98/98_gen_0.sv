module multiply_num (
parameter N = 5,
parameter WIDTH = 32,
input clk,
input rst_n, // active-low reset
input start,
input [WIDTH-1:0] data_in,
input [2:0] index,
input data_valid,
output reg [WIDTH-1:0] result,
output reg done,
output reg [2:0] state
);

// Internal registers
reg signed [WIDTH-1:0] input_values[N];
reg signed [63:0] product;
reg [N-1:0] data_received; // tracks which indices are received
reg [7:0] count; // number of valid data received
reg [2:0] state, next_state;
reg [2:0] mult_idx;
reg [WIDTH-1:0] result_reg;
reg done_flag;

// Reset and state machine
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= 3'b000; // IDLE
        count <= 8'b0;
        data_received <= {N{1'b0}};
        product <= 64'b1; // Initialize to 1
        mult_idx <= 3'b0;
        done_flag <= 1'b0;
        result_reg <= {WIDTH{1'b0}};
    end else begin
        state <= next_state;

        // Data collection in any state except COMPUTE, DIVIDE, DONE
        if (data_valid && (index >= 0 && index < N)) begin
            if (!data_received[index]) begin
                input_values[index] <= signed(data_in);
                data_received[index] <= 1;
                count <= count + 1;
            end
        end

        // Handle COMPUTE state
        if (state == 3'b010) begin // COMPUTE
            if (mult_idx < N) begin
                product <= product * input_values[mult_idx];
                mult_idx <= mult_idx + 1;
            end
        end

        // Handle DIVIDE state
        if (state == 3'b011) begin // DIVIDE
            // Perform division with rounding
            if (product >= 0) begin
                product <= (product + (N >> 1)) / N;
            end else begin
                product <= (product - (N >> 1)) / N;
            end
            // Shift right by 16 bits
            product <= product >> 16;
            // Assign result and mark as done
            result_reg <= product[WIDTH-1:0];
            done_flag <= 1'b1;
            next_state <= 3'b100; // Move to DONE next cycle
        end

        // In IDLE, check to move to COMPUTE
        if (state == 3'b000) begin
            if (count == N && start == 1) begin
                next_state <= 3'b010; // Move to COMPUTE
                done_flag <= 1'b0; // Ensure done is not set
            end
        end
    end
end

// Combinational logic for next_state and other signals
always_comb begin
    next_state = state;

    // Default: stay in current state
    case (state)
        3'b000: // IDLE
            if (count == N && start == 1) begin
                next_state <= 3'b010; // Move to COMPUTE
            end
            done_flag <= 1'b0;
            break;
        3'b010: // COMPUTE
            if (mult_idx >= N) begin
                next_state <= 3'b011; // Move to DIVIDE
            end
            done_flag <= 1'b0;
            break;
        3'b011: // DIVIDE
            // Handled in ff block
            break;
        3'b100: // DONE
            // Stay in DONE
            done_flag <= 1'b1;
            break;
        default: next_state <= 3'b000;
    endcase
end

// Output assignments
assign state = next_state;
assign done = done_flag;
assign result = result_reg;

endmodule