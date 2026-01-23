module rescale_to_unit (
    input clk,
    input rst_n, // active-low reset
    input start,
    input signed [15:0] data_in,
    input data_valid,
    input data_last,
    output reg signed [15:0] result,
    output reg result_valid,
    output reg done)
;

localparam MAX_N = 8;
localparam DATA_WIDTH = 16;

reg signed [DATA_WIDTH-1:0] buffer [0:MAX_N-1];
reg signed [DATA_WIDTH-1:0] min_val, max_val;
reg signed [DATA_WIDTH-1:0] current_data;
reg [3:0] count;
reg [3:0] output_count;
reg [2:0] state;

// State definitions
localparam IDLE = 3'b000;
localparam COLLECT = 3'b001;
localparam COMPUTE = 3'b010;
localparam OUTPUT = 3'b011;
localparam DONE = 3'b100;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        count <= 4'b0000;
        output_count <= 4'b0000;
        min_val <= 'd0;
        max_val <= 'd0;
        for (int i=0; i<MAX_N; i++) buffer[i] <= 'd0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                state <= COLLECT;
            end
        end else if (state == COLLECT) begin
            if (data_valid) begin
                buffer[count] <= data_in;
                if (count < MAX_N -1) begin
                    count <= count +1;
                end else begin
                    count <= count +1;
                    if (data_last) begin
                        state <= COMPUTE;
                    end
                end
            end
        end else if (state == COMPUTE) begin
            min_val <= buffer[0];
            max_val <= buffer[0];
            if (count >1) begin
                if (buffer[1] < min_val) min_val <= buffer[1];
                if (buffer[1] > max_val) max_val <= buffer[1];
            end
            if (count >2) begin
                if (buffer[2] < min_val) min_val <= buffer[2];
                if (buffer[2] > max_val) max_val <= buffer[2];
            end
            if (count >3) begin
                if (buffer[3] < min_val) min_val <= buffer[3];
                if (buffer[3] > max_val) max_val <= buffer[3];
            end
            if (count >4) begin
                if (buffer[4] < min_val) min_val <= buffer[4];
                if (buffer[4] > max_val) max_val <= buffer[4];
            end
            if (count >5) begin
                if (buffer[5] < min_val) min_val <= buffer[5];
                if (buffer[5] > max_val) max_val <= buffer[5];
            end
            if (count >6) begin
                if (buffer[6] < min_val) min_val <= buffer[6];
                if (buffer[6] > max_val) max_val <= buffer[6];
            end
            if (count >7) begin
                if (buffer[7] < min_val) min_val <= buffer[7];
                if (buffer[7] > max_val) max_val <= buffer[7];
            end
            if (max_val == min_val) begin
                state <= OUTPUT;
            end else begin
                state <= OUTPUT;
            end
        end else if (state == OUTPUT) begin
            if (output_count < count) begin
                if (max_val == min_val) begin
                    result <= 'd0;
                end else begin
                    result <= ((buffer[output_count] - min_val) << 16) / (max_val - min_val);
                end
                result_valid <= 1'b1;
                output_count <= output_count +1;
            end else begin
                state <= DONE;
                result_valid <= 1'b0;
            end
        end else if (state == DONE) begin
            // stay in DONE
        end
    end
end

// Assign done signal
assign done = (state == DONE);

endmodule