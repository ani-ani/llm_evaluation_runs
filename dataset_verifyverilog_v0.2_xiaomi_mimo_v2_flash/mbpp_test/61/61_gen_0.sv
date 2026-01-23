module count_substrings (
    input clk,
    input rst_n,
    input start,
    input [127:0] s,
    input [4:0] len,
    output reg [7:0] result,
    output reg done
);

    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [4:0] idx;
    reg [7:0] prefix_sum;
    reg [4:0] table [0:31]; // 32 entries, 5 bits each (supports counts 0-16)
    integer i;

    // Combinational Logic for Address Calculation
    reg signed [7:0] val;
    reg [4:0] lut_addr;

    always @(*) begin
        // Calculate val = prefix_sum - idx
        // idx is treated as unsigned 8-bit, but subtracted from signed prefix_sum
        val = prefix_sum - $signed({1'b0, idx});
        // Calculate address: val + 16.
        // Using [4:0] on val handles negative values via 2's complement wrapping.
        // Range [-15, 1] -> Address [1, 17] (safe within 0-31).
        lut_addr = val[4:0] + 16;
    end

    // State Machine and Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            // Reset table entries to 0
            for (i = 0; i < 32; i = i + 1) begin
                table[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Initialize for new computation
                        // Set count for val[-1] = 1 to 1.
                        // val[-1] = 0 - (-1) = 1. Index 1+16=17.
                        table[17] <= 1;
                        idx <= 0;
                        prefix_sum <= 0;
                        result <= 0;
                        state <= PROCESSING;
                    end
                end
                PROCESSING: begin
                    if (idx == len) begin
                        state <= DONE;
                        table[17] <= 0; // Clean up for next run
                    end else begin
                        // Core Algorithm: Read-Modify-Write in single cycle
                        // 1. Read current count from LUT (combinational) and update result
                        result <= result + table[lut_addr];
                        // 2. Update LUT entry (increment count)
                        table[lut_addr] <= table[lut_addr] + 1;
                        // 3. Update prefix sum if character is '1' (ASCII 0x31)
                        if (s[idx*8 +: 8] == 8'h31) begin
                            prefix_sum <= prefix_sum + 1;
                        end
                        // 4. Increment index
                        idx <= idx + 1;
                    end
                end
                DONE: begin
                    done <= 1;
                    // Wait for reset to restart
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule