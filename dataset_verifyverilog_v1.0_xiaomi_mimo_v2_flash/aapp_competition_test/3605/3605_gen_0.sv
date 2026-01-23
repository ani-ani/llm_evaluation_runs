module tree_diff #(
    parameter N = 8,           // Number of trees (fixed at 8)
    parameter DATA_WIDTH = 8,  // Width for tree heights (1..100 fits in 8 bits)
    parameter K_WIDTH = 4      // Width for k input (k <= 8)
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    // Input array: 8 individual ports, each 8 bits
    input wire [DATA_WIDTH-1:0] arr_0,
    input wire [DATA_WIDTH-1:0] arr_1,
    input wire [DATA_WIDTH-1:0] arr_2,
    input wire [DATA_WIDTH-1:0] arr_3,
    input wire [DATA_WIDTH-1:0] arr_4,
    input wire [DATA_WIDTH-1:0] arr_5,
    input wire [DATA_WIDTH-1:0] arr_6,
    input wire [DATA_WIDTH-1:0] arr_7,
    input wire [K_WIDTH-1:0] k,
    output reg [DATA_WIDTH-1:0] result,
    output reg done
);

// Internal registers for array storage
reg [DATA_WIDTH-1:0] arr_reg [0:N-1];
reg [K_WIDTH-1:0] k_reg;
reg [DATA_WIDTH-1:0] min_diff;
reg [DATA_WIDTH-1:0] cur_min, cur_max;
reg [3:0] i;          // window start index
reg [3:0] j;          // inner loop index
reg [2:0] state;

// State definitions
localparam [2:0] IDLE = 3'b000;
localparam [2:0] NEXT_WINDOW = 3'b001;
localparam [2:0] COMPUTE_WINDOW = 3'b010;
localparam [2:0] UPDATE_DIFF = 3'b011;
localparam [2:0] DONE = 3'b100;

integer idx;

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset
        state <= IDLE;
        done <= 1'b0;
        result <= 8'b0;
        // Reset array registers
        for (idx = 0; idx < N; idx = idx + 1)
            arr_reg[idx] <= 8'b0;
        k_reg <= 8'b0;
        min_diff <= 8'b0;
        cur_min <= 8'b0;
        cur_max <= 8'b0;
        i <= 4'b0;
        j <= 4'b0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    // Capture input array into registers
                    arr_reg[0] <= arr_0;
                    arr_reg[1] <= arr_1;
                    arr_reg[2] <= arr_2;
                    arr_reg[3] <= arr_3;
                    arr_reg[4] <= arr_4;
                    arr_reg[5] <= arr_5;
                    arr_reg[6] <= arr_6;
                    arr_reg[7] <= arr_7;
                    k_reg <= k;
                    // Initialize min_diff to max possible
                    min_diff <= 8'hFF;
                    i <= 4'b0;
                    state <= NEXT_WINDOW;
                end
            end

            NEXT_WINDOW: begin
                // Check if more windows exist
                if (i <= N - k_reg) begin
                    // Start new window
                    cur_min <= 8'hFF;  // Initialize to max
                    cur_max <= 8'h00;  // Initialize to min
                    j <= i;            // Start inner loop
                    state <= COMPUTE_WINDOW;
                end else begin
                    // All windows processed
                    state <= DONE;
                end
            end

            COMPUTE_WINDOW: begin
                // Update min and max with current element
                if (arr_reg[j] < cur_min)
                    cur_min <= arr_reg[j];
                if (arr_reg[j] > cur_max)
                    cur_max <= arr_reg[j];
                // Increment j
                j <= j + 1;
                // Check if finished this window
                if (j + 1 < i + k_reg)
                    state <= COMPUTE_WINDOW; // continue
                else
                    state <= UPDATE_DIFF;   // window done
            end

            UPDATE_DIFF: begin
                // Compute diff and update min_diff if smaller
                if (cur_max - cur_min < min_diff)
                    min_diff <= cur_max - cur_min;
                // Move to next window
                i <= i + 1;
                state <= NEXT_WINDOW;
            end

            DONE: begin
                result <= min_diff;
                done <= 1'b1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule