module aladin_device (
    input clk,
    input rst_n,
    input start,
    input [1:0] cmd_type,
    input [15:0] L, R,
    input [19:0] A, B,
    output reg [31:0] result,
    output reg done
);

parameter BOXES = 16;

// Box storage: 1-indexed, boxes 1 to 16
reg [31:0] box [1:16];

// State machine
reg [1:0] state;
localparam [1:0] IDLE = 2'd0;
localparam [1:0] UPDATE = 2'd1;
localparam [1:0] QUERY = 2'd2;

reg [15:0] current_index;
reg [15:0] step;
reg [31:0] sum;
integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all boxes to 0
        for (i = 1; i <= 16; i = i + 1) begin
            box[i] <= 32'd0;
        end
        state <= IDLE;
        result <= 32'd0;
        done <= 1'b0;
        current_index <= 16'd0;
        step <= 16'd0;
        sum <= 32'd0;
    end else begin
        done <= 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    if (cmd_type == 2'd1) begin
                        current_index <= L;
                        step <= 16'd1;
                        state <= UPDATE;
                    end else if (cmd_type == 2'd2) begin
                        current_index <= L;
                        sum <= 32'd0;
                        state <= QUERY;
                    end else begin
                        state <= IDLE;
                    end
                end
            end

            UPDATE: begin
                if (current_index <= R && current_index <= BOXES) begin
                    box[current_index] <= (step * A) % B;
                    current_index <= current_index + 16'd1;
                    step <= step + 16'd1;
                end else begin
                    state <= IDLE;
                    done <= 1'b1;
                end
            end

            QUERY: begin
                if (current_index <= R && current_index <= BOXES) begin
                    sum <= sum + box[current_index];
                    current_index <= current_index + 16'd1;
                end else begin
                    state <= IDLE;
                    result <= sum;
                    done <= 1'b1;
                end
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule