module tuple_size (
    input clk,
    input rst_n,
    input start,
    input [3:0] num_elements,
    input [7:0] element_widths [0:7],
    output reg [15:0] result,
    output reg done
);

reg [15:0] sum;
reg [15:0] total_result;
reg [1:0] state;
reg [3:0] cycle_count;

localparam IDLE = 2'b00;
localparam PROCESSING = 2'b01;
localparam DONE = 2'b10;

assign result = total_result;

always @(posedge clk) begin
    if (!rst_n) begin
        sum <= 16'b0;
        total_result <= 16'b0;
        state <= IDLE;
        cycle_count <= 4'd0;
        done <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= PROCESSING;
                    sum <= 16'b0;
                    cycle_count <= 4'd0;
                end
                done <= 0;
            end
            PROCESSING: begin
                if (cycle_count < num_elements) begin
                    sum <= sum + element_widths[cycle_count];
                end
                cycle_count <= cycle_count + 1;
                if (cycle_count == 4'd8) begin
                    state <= DONE;
                    total_result <= sum + 20;
                    done <= 1;
                end else begin
                    done <= 0;
                end
            end
            DONE: begin
                done <= 1;
            end
        endcase
    end
end
endmodule
