module max_points #(
    parameter MAX_VAL = 64,       // Maximum value (0 to 63)
    parameter MAX_INPUT_LEN = 16, // Maximum number of input elements
    parameter VAL_BITS = 6,       // Bits to represent a value
    parameter CNT_BITS = 5,       // Bits for frequency count (max 16)
    parameter RESULT_BITS = 16    // Bits for result
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [VAL_BITS-1:0] arr [0:MAX_INPUT_LEN-1],
    input wire [3:0] len,
    output wire [RESULT_BITS-1:0] result,
    output wire done
);
    // State definitions
    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] LOAD = 2'b01;
    localparam [1:0] DP = 2'b10;
    localparam [1:0] DONE = 2'b11;

    reg [1:0] state, next_state;
    reg [3:0] load_idx;
    reg [5:0] dp_idx;
    reg [CNT_BITS-1:0] freq [0:MAX_VAL-1];
    reg [RESULT_BITS-1:0] dp_prev, dp_curr;
    reg [RESULT_BITS-1:0] result_reg;
    reg done_reg;

    // Combinational DP calculation
    wire [RESULT_BITS-1:0] contribution;
    wire [RESULT_BITS-1:0] dp_new;

    assign contribution = dp_idx * freq[dp_idx];
    assign dp_new = (dp_curr > dp_prev + contribution) ? dp_curr : (dp_prev + contribution);

    assign result = result_reg;
    assign done = done_reg;

    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            load_idx <= 0;
            dp_idx <= 0;
            dp_prev <= 0;
            dp_curr <= 0;
            result_reg <= 0;
            done_reg <= 0;
            // Clear frequency array
            for (integer i = 0; i < MAX_VAL; i = i + 1) begin
                freq[i] <= 0;
            end
        end else begin
            done_reg <= 0; // default, may be overridden
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD;
                        load_idx <= 0;
                        // Clear frequency array for new computation
                        for (integer i = 0; i < MAX_VAL; i = i + 1) begin
                            freq[i] <= 0;
                        end
                    end
                end
                LOAD: begin
                    if (load_idx < len) begin
                        // Increment frequency of the current element
                        freq[arr[load_idx]] <= freq[arr[load_idx]] + 1;
                        load_idx <= load_idx + 1;
                    end else begin
                        state <= DP;
                        dp_idx <= 0;
                        dp_prev <= 0;
                        dp_curr <= 0;
                    end
                end
                DP: begin
                    if (dp_idx < MAX_VAL) begin
                        // Update dp registers
                        dp_prev <= dp_curr;
                        dp_curr <= dp_new;
                        dp_idx <= dp_idx + 1;
                    end else begin
                        state <= DONE;
                        result_reg <= dp_curr;
                        done_reg <= 1; // Pulse done
                    end
                end
                DONE: begin
                    state <= IDLE;
                    // done_reg will be cleared in next cycle (already set to 0 at start of always)
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule