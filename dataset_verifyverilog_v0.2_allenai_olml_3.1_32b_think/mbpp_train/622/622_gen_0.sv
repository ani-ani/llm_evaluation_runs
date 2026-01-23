module median_two_sorted_arrays (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [2:0] n,
    input [7:0] arr1 [0:7],
    input [7:0] arr2 [0:7],
    output reg [31:0] result,
    output reg done
);

// Registers
reg [1:0] state; // IDLE=00, PROCESSING=01, DONE=10
reg [7:0] i, j;
reg [3:0] count; // since n can be up to 7, count up to 8 (4 bits)
reg [7:0] m1, m2;

// State definitions
localparam IDLE = 2'b00;
localparam PROCESSING = 2'b01;
localparam DONE = 2'b10;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        i <= 0;
        j <= 0;
        count <= 0;
        m1 <= 0;
        m2 <= 0;
        result <= 0;
        done <= 0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                state <= PROCESSING;
                i <= 0;
                j <= 0;
                count <= 0;
                m1 <= 0;
                m2 <= 0;
            end
        end else if (state == PROCESSING) begin
            // Compute next i, j, and current element
            reg [7:0] i_next, j_next;
            reg [7:0] current;

            i_next = i;
            j_next = j;
            current = 0;

            if (i < n && (j >= n || arr1[i] <= arr2[j])) begin
                current = arr1[i];
                i_next = i + 1;
            end else if (j < n) begin
                current = arr2[j];
                j_next = j + 1;
            end

            // Update m1, m2, count
            m1 <= m2;
            m2 <= current;
            count <= count + 1;

            i <= i_next;
            j <= j_next;

            if (count + 1 == n + 1) begin
                state <= DONE;
            end else begin
                state <= PROCESSING;
            end
        end else if (state == DONE) begin
            // Compute result
            result <= ((m1 + m2) << 16) >> 1;
            done <= 1;
        end
    end
endmodule