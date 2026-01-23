module reverse_array_upto_k (
    input clk,
    input rst_n, // active low
    input start,
    input [2:0] k,
    input [0:7][7:0] arr_in,
    output reg [7:0] arr_out [0:7],
    output reg done
);

// Internal registers
reg [7:0] arr_out_reg [0:7];
reg [2:0] k_captured;
reg [0:7][7:0] arr_in_captured [0:7];
reg [1:0] state; // IDLE=0, PROCESSING=1, DONE=2
reg [1:0] swap_left;
reg [1:0] swap_right;
reg [2:0] swap_remaining;

// State machine
always_ff @(posedge clk) begin
    if (!rst_n) begin
        arr_out_reg <= 0;
        k_captured <= 0;
        arr_in_captured <= 0;
        state <= 0;
        swap_left <= 0;
        swap_right <= 0;
        swap_remaining <= 0;
    end else begin
        case (state)
            0: // IDLE
                if (start) begin
                    // Capture inputs and load output
                    arr_in_captured <= arr_in;
                    k_captured <= k;
                    arr_out_reg <= arr_in_captured;
                    // Initialize swap variables
                    swap_left <= 0;
                    swap_right <= k_captured - 1;
                    swap_remaining <= k_captured >> 1; // Number of swaps needed
                    state <= 1; // PROCESSING
                end
            end
            1: // PROCESSING
                if (swap_remaining > 0 && swap_left < swap_right) begin
                    // Swap the elements
                    {arr_out_reg[swap_left], arr_out_reg[swap_right]} <= {arr_out_reg[swap_right], arr_out_reg[swap_left]};
                    swap_left <= swap_left + 1;
                    swap_right <= swap_right - 1;
                    swap_remaining <= swap_remaining - 1;
                end else begin
                    state <= 2; // DONE
                end
            end
            2: // DONE
                // Stay in DONE, done is set below
            endcase
        end
    end
end

// Assign outputs
assign arr_out = arr_out_reg;
assign done = (state == 2);
endmodule