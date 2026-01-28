module DistinctGCDCounter (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:15],
    input [3:0] len,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] INIT_LOOP  = 3'd1;
    localparam [2:0] CALC_GCD   = 3'd2;
    localparam [2:0] MARK_GCD   = 3'd3;
    localparam [2:0] COUNT_GCD  = 3'd4;
    localparam [2:0] FINISH     = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [3:0] i;           // Outer loop index (start position)
    reg [3:0] j;           // Inner loop index (end position)
    reg [7:0] current_gcd; // GCD for current subarray
    reg [255:0] gcd_set;   // Bit vector for tracking seen GCDs
    reg [7:0] count;       // Final count
    reg [7:0] loop_counter; // General loop counter
    reg [7:0] gcd_a;
    reg [7:0] gcd_b;
    reg [7:0] temp_gcd;
    reg gcd_done;
    reg [7:0] gcd_counter;

    // GCD calculation using iterative Euclidean algorithm
    // Max iterations for 8-bit: ~24 (log2(256))
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gcd_a <= 8'd0;
            gcd_b <= 8'd0;
            temp_gcd <= 8'd0;
            gcd_done <= 1'b0;
            gcd_counter <= 8'd0;
        end else begin
            if (state == CALC_GCD && !gcd_done) begin
                if (gcd_counter == 8'd0) begin
                    // First cycle: initialize
                    if (gcd_b == 8'd0) begin
                        temp_gcd <= gcd_a;
                        gcd_done <= 1'b1;
                    end else if (gcd_a == 8'd0) begin
                        temp_gcd <= gcd_b;
                        gcd_done <= 1'b1;
                    end else begin
                        gcd_counter <= gcd_counter + 8'd1;
                    end
                end else begin
                    // Euclidean algorithm loop
                    if (gcd_b != 8'd0) begin
                        if (gcd_a > gcd_b) begin
                            gcd_a <= gcd_b;
                            gcd_b <= gcd_a - gcd_b;
                        end else begin
                            gcd_b <= gcd_b - gcd_a;
                        end
                        gcd_counter <= gcd_counter + 8'd1;
                    end else begin
                        temp_gcd <= gcd_a;
                        gcd_done <= 1'b1;
                    end
                end
            end else if (state != CALC_GCD) begin
                gcd_done <= 1'b0;
                gcd_counter <= 8'd0;
            end
        end
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            current_gcd <= 8'd0;
            gcd_set <= 256'd0;
            count <= 8'd0;
            loop_counter <= 8'd0;
            gcd_a <= 8'd0;
            gcd_b <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT_LOOP;
                        gcd_set <= 256'd0;
                        i <= 4'd0;
                        j <= 4'd0;
                        current_gcd <= 8'd0;
                        loop_counter <= 8'd0;
                    end
                end

                INIT_LOOP: begin
                    // Check outer loop bounds
                    if (i < len) begin
                        j <= i;
                        current_gcd <= 8'd0;
                        state <= CALC_GCD;
                    end else begin
                        state <= COUNT_GCD;
                    end
                end

                CALC_GCD: begin
                    if (gcd_done) begin
                        current_gcd <= temp_gcd;
                        state <= MARK_GCD;
                    end else begin
                        if (gcd_counter == 8'd0) begin
                            gcd_a <= current_gcd;
                            gcd_b <= arr[j];
                        end
                    end
                end

                MARK_GCD: begin
                    // Mark the GCD in the set
                    gcd_set[current_gcd] <= 1'b1;
                    j <= j + 4'd1;
                    // Check if we need to continue inner loop
                    if (j < len - 4'd1) begin
                        state <= CALC_GCD;
                    end else begin
                        i <= i + 4'd1;
                        state <= INIT_LOOP;
                    end
                end

                COUNT_GCD: begin
                    // Count the number of set bits in gcd_set
                    // Use loop counter to iterate through 256 bits
                    if (loop_counter < 8'd255) begin
                        if (gcd_set[loop_counter]) begin
                            count <= count + 8'd1;
                        end
                        loop_counter <= loop_counter + 8'd1;
                    end else begin
                        // Last bit check
                        if (gcd_set[8'd255]) begin
                            count <= count + 8'd1;
                        end
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= count;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule