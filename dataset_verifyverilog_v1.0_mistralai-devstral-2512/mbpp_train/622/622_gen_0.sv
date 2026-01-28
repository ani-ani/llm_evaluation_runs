module median_of_two_sorted_arrays(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [7:0] arr1 [0:15],
    input [7:0] arr2 [0:15],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state;
    reg [3:0] i;
    reg [3:0] j;
    reg [3:0] count;
    reg [7:0] m1;
    reg [7:0] m2;
    reg [7:0] val1;
    reg [7:0] val2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 4'd0;
            j <= 4'd0;
            count <= 4'd0;
            m1 <= 8'd0;
            m2 <= 8'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPARE;
                        i <= 4'd0;
                        j <= 4'd0;
                        count <= 4'd0;
                        m1 <= 8'd0;
                        m2 <= 8'd0;
                    end
                end

                COMPARE: begin
                    // Determine current values
                    if (i < n) begin
                        val1 = arr1[i];
                    end else begin
                        val1 = 8'd255; // Large value to force arr2 selection
                    end

                    if (j < n) begin
                        val2 = arr2[j];
                    end else begin
                        val2 = 8'd255; // Large value to force arr1 selection
                    end

                    // Compare and update
                    if (val1 < val2) begin
                        m2 = m1;
                        m1 = val1;
                        i = i + 4'd1;
                    end else begin
                        m2 = m1;
                        m1 = val2;
                        j = j + 4'd1;
                    end

                    count = count + 4'd1;

                    // Check if we've processed n+1 elements
                    if (count == n + 4'd1) begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    // Calculate median in Q8.8 format
                    // (m1 + m2) / 2 = (m1 + m2) * 128 (since 128 = 2^7)
                    result <= ({m1, 8'd0} + {m2, 8'd0}) >> 1;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule