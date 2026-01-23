module max_val_heterogeneous (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [2:0] num_elements,
    input [7:0] array_data [0:7],
    output reg [7:0] max_int_result,
    output reg done,
    output reg valid
);

    // Registers
    reg [2:0] state; // IDLE=0, SCAN=1, UPDATE_MAX=2, DONE=3
    reg [2:0] index;
    reg [7:0] max_val;
    reg done_reg;
    reg valid_reg;

    // State definitions
    localparam IDLE = 3'b000;
    localparam SCAN = 3'b001;
    localparam UPDATE_MAX = 3'b010;
    localparam DONE = 3'b100;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'b000;
            max_val <= 8'b00000000;
            done_reg <= 1'b0;
            valid_reg <= 1'b0;
        end else begin
            if (state == IDLE) begin
                if (start) begin
                    state <= SCAN;
                    index <= 3'b000;
                    max_val <= 8'b00000000;
                end
            end else if (state == SCAN) begin
                if (index < 3'b100) begin // process all 8 elements
                    // Check current element
                    if (array_data[index] != 8'b000 && index < num_elements) begin
                        if (array_data[index] > max_val) begin
                            max_val <= array_data[index];
                            state <= UPDATE_MAX;
                        end
                        else begin
                            state <= SCAN;
                        end
                    end else begin
                        state <= SCAN;
                    end
                    index <= index + 1;
                end else begin
                    state <= DONE;
                    done_reg <= 1'b1;
                    valid_reg <= (max_val != 8'b000) ? 1'b1 : 1'b0;
                end
            end else if (state == UPDATE_MAX) begin
                state <= SCAN;
            end else if (state == DONE) begin
                // stay in DONE
            end
        end
    end

    // Assign outputs
    assign max_int_result = max_val;
    assign done = done_reg;
    assign valid = valid_reg;

endmodule