module last_position(
    input clk,
    input rst_n,
    input start,
    input [7:0] target,
    input [7:0][7:0] arr,
    output reg [2:0] position,
    output reg found,
    output reg done
);

    // State parameters
    localparam IDLE = 2'b00;
    localparam SEARCH = 2'b01;
    localparam DONE = 2'b10;

    // Internal registers
    reg [1:0] state_reg;
    reg [2:0] low_reg, high_reg, mid_reg, result_reg;
    reg [1:0] step_reg;

    // Calculate mid index as (low + high) / 2
    wire [2:0] mid_wire;
    assign mid_wire = (low_reg + high_reg) >> 1;

    // State machine
    always @(posedge clk) begin
        if (!rst_n) begin
            state_reg <= IDLE;
            position <= 3'b000;
            found <= 1'b0;
            done <= 1'b0;
            low_reg <= 3'b000;
            high_reg <= 3'b000;
            mid_reg <= 3'b000;
            result_reg <= 3'b100; // 4: indicates not found
            step_reg <= 2'b00;
        end
        else begin
            case (state_reg)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state_reg <= SEARCH;
                        low_reg <= 3'b000;   // 0
                        high_reg <= 3'b111;   // 7
                        result_reg <= 3'b100; // 4: indicates not found
                        step_reg <= 2'b00;    // 0
                    end
                end

                SEARCH: begin
                    mid_reg <= mid_wire;
                    if (arr[mid_reg] == target) begin
                        result_reg <= mid_reg;
                        low_reg <= mid_reg + 1;
                    end else if (arr[mid_reg] < target) begin
                        low_reg <= mid_reg + 1;
                    end else begin
                        high_reg <= mid_reg - 1;
                    end

                    step_reg <= step_reg + 1;
                    if (step_reg == 2'b11) begin
                        state_reg <= DONE;
                    end
                end

                DONE: begin
                    position <= result_reg;
                    found <= (result_reg != 3'b100) ? 1'b1 : 1'b0;
                    done <= 1'b1;
                    state_reg <= IDLE;
                end
            endcase
        end
    end
endmodule